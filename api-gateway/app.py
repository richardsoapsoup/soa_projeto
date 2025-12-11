from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import requests
import consul
import json
import time
from circuitbreaker import circuit
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
from confluent_kafka import Producer
from consul import Consul
from kafka import KafkaProducer, KafkaConsumer
from kafka.errors import NoBrokersAvailable
from kafka.admin import KafkaAdminClient, NewTopic
import logging
from contextlib import asynccontextmanager
import asyncio

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

REQUEST_COUNT = Counter('requests_total', 'Total HTTP Requests', ['method', 'endpoint', 'status_code'])
REQUEST_LATENCY = Histogram('request_latency_seconds', 'Request latency', ['method', 'endpoint'])

kafka_config = {
    'bootstrap.servers': 'kafka:29092'
}
kafka_producer = Producer(kafka_config)

class UserCreate(BaseModel):
    username: str
    password: str

class UserLogin(BaseModel):
    username: str
    password: str

class PostCreate(BaseModel):
    text: str
    user_id: int

def wait_for_consul():
    max_retries = 30
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            consul_client = Consul(host='consul', port=8500)
            consul_client.agent.self()
            logger.info("Consul disponivel")
            return True
        except Exception as e:
            retry_count += 1
            logger.warning(f"Consul nao disponivel, tentativa {retry_count}/{max_retries}: {e}")
            time.sleep(2)
    
    logger.error("Consul nao ficou disponivel a tempo")
    return False

def wait_for_kafka():
    max_retries = 30
    retry_count = 0
    bootstrap_servers = 'kafka:29092'
    
    logger.info("Aguardando Kafka ficar disponivel")
    
    while retry_count < max_retries:
        try:
            consumer = KafkaConsumer(
                bootstrap_servers=[bootstrap_servers],
                request_timeout_ms=10000,
                session_timeout_ms=10000,
                retry_backoff_ms=500,
                api_version_auto_timeout_ms=30000
            )
            
            topics = consumer.topics()
            logger.info(f"Kafka disponivel. Topicos: {topics}")
            consumer.close()
            
            create_kafka_topics(bootstrap_servers)
            
            if test_kafka_connection(bootstrap_servers):
                logger.info("Kafka operacional")
                return True
                
        except NoBrokersAvailable as e:
            retry_count += 1
            logger.warning(f"Kafka nao disponivel, tentativa {retry_count}/{max_retries}: {e}")
            time.sleep(3)
        except Exception as e:
            retry_count += 1
            logger.warning(f"Erro ao conectar com Kafka, tentativa {retry_count}/{max_retries}: {e}")
            time.sleep(3)
    
    logger.error("Kafka nao ficou disponivel a tempo")
    return False

def create_kafka_topics(bootstrap_servers):
    try:
        admin_client = KafkaAdminClient(
            bootstrap_servers=[bootstrap_servers],
            client_id='soa_api_gateway'
        )
        
        topic_list = [
            NewTopic(
                name="user-events",
                num_partitions=1,
                replication_factor=1,
                topic_configs={'retention.ms': '604800000'}
            ),
            NewTopic(
                name="post-events", 
                num_partitions=1,
                replication_factor=1,
                topic_configs={'retention.ms': '604800000'}
            ),
            NewTopic(
                name="service-logs",
                num_partitions=1, 
                replication_factor=1,
                topic_configs={'retention.ms': '259200000'}
            )
        ]
        
        try:
            admin_client.create_topics(new_topics=topic_list, validate_only=False)
            logger.info("Topicos Kafka criados")
        except Exception as e:
            logger.info(f"Topicos provavelmente ja existem: {e}")
            
        admin_client.close()
        
    except Exception as e:
        logger.warning(f"Erro ao criar topicos Kafka: {e}")

def test_kafka_connection(bootstrap_servers):
    try:
        test_topic = "health-check"
        test_message = {"service": "api-gateway", "timestamp": time.time(), "status": "healthy"}
        
        producer = KafkaProducer(
            bootstrap_servers=[bootstrap_servers],
            value_serializer=lambda v: str(v).encode('utf-8'),
            retries=3,
            request_timeout_ms=10000
        )
        
        future = producer.send(test_topic, value=test_message)
        producer.flush(timeout=10)
        
        try:
            future.get(timeout=10)
            logger.info("Teste de producao Kafka: OK")
        except Exception as e:
            logger.warning(f"Teste de producao Kafka falhou: {e}")
            return False
        
        producer.close()
        
        consumer = KafkaConsumer(
            test_topic,
            bootstrap_servers=[bootstrap_servers],
            auto_offset_reset='earliest',
            enable_auto_commit=False,
            consumer_timeout_ms=5000
        )
        
        message_count = 0
        for message in consumer:
            message_count += 1
            break
        
        consumer.close()
        
        logger.info("Teste de conexao Kafka completo: OK")
        return True
        
    except Exception as e:
        logger.warning(f"Teste de conexao Kafka falhou: {e}")
        return False

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Iniciando API Gateway")
    wait_for_consul()
    wait_for_kafka()
    logger.info("API Gateway iniciado")
    yield
    logger.info("Parando API Gateway")

app = FastAPI(title="API Gateway", lifespan=lifespan)

consul_client = consul.Consul(host='consul', port=8500)

def get_service_url(service_name: str):
    try:
        _, services = consul_client.catalog.service(service_name)
        if services:
            service = services[0]
            return f"http://{service['ServiceAddress']}:{service['ServicePort']}"
        return None
    except Exception as e:
        logging.error(f"Erro no service discovery: {e}")
        return None

@circuit(failure_threshold=5, expected_exception=HTTPException)
def call_service(service_name: str, method: str, endpoint: str, **kwargs):
    start_time = time.time()
    
    service_url = get_service_url(service_name)
    if not service_url:
        raise HTTPException(status_code=503, detail=f"Service {service_name} unavailable")
    
    url = f"{service_url}{endpoint}"
    
    try:
        if method.upper() == 'GET':
            response = requests.get(url, **kwargs)
        elif method.upper() == 'POST':
            response = requests.post(url, **kwargs)
        elif method.upper() == 'PUT':
            response = requests.put(url, **kwargs)
        elif method.upper() == 'DELETE':
            response = requests.delete(url, **kwargs)
        else:
            raise HTTPException(status_code=400, detail="Method not supported")
        
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status_code=response.status_code).inc()
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(time.time() - start_time)
        
        return response
        
    except requests.exceptions.RequestException as e:
        logging.error(f"Error calling {service_name}: {e}")
        raise HTTPException(status_code=503, detail=f"Service {service_name} error")

def kafka_delivery_report(err, msg):
    if err is not None:
        logging.error(f'Message delivery failed: {err}')
    else:
        logging.info(f'Message delivered to {msg.topic()} [{msg.partition()}]')

@app.post("/usuarios/registrar")
async def registrar_usuario(user: UserCreate):
    response = call_service('usuarios-service', 'POST', '/usuarios/registrar', json=user.dict())
    
    if response.status_code == 201:
        kafka_producer.produce(
            'user-events',
            key=user.username,
            value=json.dumps({
                'event_type': 'USER_REGISTERED',
                'username': user.username,
                'timestamp': time.time()
            }),
            callback=kafka_delivery_report
        )
        kafka_producer.poll(0)
    
    return response.json(), response.status_code

@app.post("/usuarios/login")
async def login_usuario(login: UserLogin):
    response = call_service('usuarios-service', 'POST', '/usuarios/login', json=login.dict())
    return response.json(), response.status_code

@app.get("/usuarios/{user_id}")
async def get_usuario(user_id: int):
    response = call_service('usuarios-service', 'GET', f'/usuarios/{user_id}')
    return response.json(), response.status_code

@app.post("/posts")
async def criar_post(post: PostCreate):
    response = call_service('posts-service', 'POST', '/posts', json=post.dict())
    
    if response.status_code == 201:
        kafka_producer.produce(
            'post-events',
            key=str(post.user_id),
            value=json.dumps({
                'event_type': 'POST_CREATED',
                'user_id': post.user_id,
                'timestamp': time.time()
            }),
            callback=kafka_delivery_report
        )
        kafka_producer.poll(0)
    
    return response.json(), response.status_code

@app.get("/posts")
async def listar_posts():
    response = call_service('posts-service', 'GET', '/posts')
    return response.json(), response.status_code

@app.get("/posts/{post_id}")
async def get_post(post_id: int):
    response = call_service('posts-service', 'GET', f'/posts/{post_id}')
    return response.json(), response.status_code

@app.get("/usuarios/{user_id}/posts")
async def get_posts_usuario(user_id: int):
    response = call_service('posts-service', 'GET', f'/posts/usuario/{user_id}')
    return response.json(), response.status_code

@app.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/health")
async def health():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)