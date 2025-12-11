from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import consul
import json
from typing import Dict, List
import logging
from prometheus_client import Counter, Histogram, generate_latest
from fastapi.responses import Response
from confluent_kafka import Consumer, Producer
import threading
import time
import asyncio
from contextlib import asynccontextmanager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

posts_db: Dict[int, dict] = {}
post_id_counter = 1

POST_CREATIONS = Counter('post_creations_total', 'Total post creations')
POST_VIEWS = Counter('post_views_total', 'Total post views')

kafka_config = {
    'bootstrap.servers': 'kafka:29092',
    'group.id': 'posts-service'
}

class PostCreate(BaseModel):
    text: str
    user_id: int

def register_service():
    try:
        consul_client = consul.Consul(host='consul', port=8500)
        
        services = consul_client.agent.services()
        if 'posts-service-1' in services:
            consul_client.agent.service.deregister('posts-service-1')
        
        consul_client.agent.service.register(
            'posts-service',
            service_id='posts-service-1',
            address='posts-service',
            port=8002,
            tags=['soa', 'posts', 'rest'],
            check=consul.Check.http(
                url=f'http://posts-service:8002/health',
                interval='10s',
                timeout='5s',
                deregister='30s'
            )
        )
        logger.info("Serviço de posts registrado no Consul")
    except Exception as e:
        logger.error(f"Erro ao registrar serviço no Consul: {e}")

def wait_for_consul():
    max_retries = 30
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            consul_client = consul.Consul(host='consul', port=8500)
            consul_client.agent.self()
            logger.info("Consul está disponível")
            return True
        except Exception as e:
            retry_count += 1
            logger.warning(f"Consul não disponível, tentativa {retry_count}/{max_retries}: {e}")
            time.sleep(2)
    
    logger.error("Consul não ficou disponível a tempo")
    return False

def wait_for_kafka():
    max_retries = 30
    retry_count = 0
    bootstrap_servers = 'kafka:29092'
    
    logger.info("Aguardando Kafka ficar disponível...")
    
    while retry_count < max_retries:
        try:
            from kafka import KafkaConsumer
            from kafka.errors import NoBrokersAvailable
            
            consumer = KafkaConsumer(
                bootstrap_servers=[bootstrap_servers],
                request_timeout_ms=10000
            )
            topics = consumer.topics()
            logger.info(f"Kafka está disponível. Tópicos: {topics}")
            consumer.close()
            return True
                
        except NoBrokersAvailable as e:
            retry_count += 1
            logger.warning(f"Kafka não disponível, tentativa {retry_count}/{max_retries}: {e}")
            time.sleep(3)
        except Exception as e:
            retry_count += 1
            logger.warning(f"Erro ao conectar com Kafka, tentativa {retry_count}/{max_retries}: {e}")
            time.sleep(3)
    
    logger.error("Kafka não ficou disponível a tempo")
    return False

def kafka_consumer():
    try:
        consumer = Consumer({
            'bootstrap.servers': 'kafka:29092',
            'group.id': 'posts-service-consumer',
            'auto.offset.reset': 'earliest'
        })
        
        consumer.subscribe(['post-events', 'user-events'])
        
        while True:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                logger.error(f"Consumer error: {msg.error()}")
                continue
            
            try:
                event = json.loads(msg.value().decode('utf-8'))
                logger.info(f"Evento recebido no posts-service: {event}")
            except Exception as e:
                logger.error(f"Erro processando evento: {e}")
    except Exception as e:
        logger.error(f"Erro no consumidor Kafka: {e}")

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Iniciando Serviço de Posts...")
    
    logger.info("Aguardando dependências...")
    wait_for_consul()
    wait_for_kafka()
    
    register_service()
    
    kafka_thread = threading.Thread(target=kafka_consumer, daemon=True)
    kafka_thread.start()
    logger.info("✅ Serviço de posts iniciado")
    
    yield
    
    logger.info("Parando Serviço de Posts...")

app = FastAPI(
    title="Posts Service",
    description="Serviço de gerenciamento de posts",
    version="1.0.0",
    lifespan=lifespan
)

@app.post("/posts")
async def criar_post(post: PostCreate):
    global post_id_counter
    
    post_data = {
        'id': post_id_counter,
        'text': post.text,
        'user_id': post.user_id,
        'created_at': time.time()
    }
    
    posts_db[post_id_counter] = post_data
    post_id_counter += 1
    
    POST_CREATIONS.inc()
    
    return {"id": post_data['id'], "text": post_data['text'], "user_id": post_data['user_id']}

@app.get("/posts")
async def listar_posts():
    posts = list(posts_db.values())
    POST_VIEWS.inc()
    return posts

@app.get("/posts/{post_id}")
async def get_post(post_id: int):
    post = posts_db.get(post_id)
    if not post:
        raise HTTPException(status_code=404, detail="Post não encontrado")
    
    POST_VIEWS.inc()
    return post

@app.get("/posts/usuario/{user_id}")
async def get_posts_usuario(user_id: int):
    user_posts = [post for post in posts_db.values() if post['user_id'] == user_id]
    POST_VIEWS.inc()
    return user_posts

@app.get("/health")
async def health():
    return {"status": "healthy"}

@app.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)