from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
import consul
import bcrypt
import json
from typing import Dict
import logging
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
from confluent_kafka import Consumer, Producer
import threading
import time
import asyncio
from contextlib import asynccontextmanager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

users_db: Dict[int, dict] = {}
user_id_counter = 1

USER_REGISTRATIONS = Counter('user_registrations_total', 'Total user registrations')
USER_LOGINS = Counter('user_logins_total', 'Total user logins', ['status'])

kafka_config = {
    'bootstrap.servers': 'kafka:29092',
    'group.id': 'usuarios-service'
}

class UserCreate(BaseModel):
    username: str
    password: str

class UserLogin(BaseModel):
    username: str
    password: str

def register_service():
    try:
        consul_client = consul.Consul(host='consul', port=8500)
        
        services = consul_client.agent.services()
        if 'usuarios-service-1' in services:
            consul_client.agent.service.deregister('usuarios-service-1')
        
        consul_client.agent.service.register(
            'usuarios-service',
            service_id='usuarios-service-1',
            address='usuarios-service',
            port=8001,
            tags=['soa', 'users', 'rest'],
            check=consul.Check.http(
                url=f'http://usuarios-service:8001/health',
                interval='10s',
                timeout='5s',
                deregister='30s'
            )
        )
        logger.info("Serviço de usuários registrado no Consul")
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
            'group.id': 'usuarios-service-consumer',
            'auto.offset.reset': 'earliest'
        })
        
        consumer.subscribe(['user-events'])
        
        while True:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                logger.error(f"Consumer error: {msg.error()}")
                continue
            
            try:
                event = json.loads(msg.value().decode('utf-8'))
                logger.info(f"Evento recebido: {event}")
            except Exception as e:
                logger.error(f"Erro processando evento: {e}")
    except Exception as e:
        logger.error(f"Erro no consumidor Kafka: {e}")

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Iniciando Serviço de Usuários...")
    
    logger.info("Aguardando dependências...")
    wait_for_consul()
    wait_for_kafka()
    
    register_service()
    
    kafka_thread = threading.Thread(target=kafka_consumer, daemon=True)
    kafka_thread.start()
    logger.info("Serviço de usuários iniciado")
    
    yield  
    
    logger.info("Parando Serviço de Usuários...")

app = FastAPI(
    title="Usuarios Service",
    description="Serviço de gerenciamento de usuários",
    version="1.0.0",
    lifespan=lifespan
)

@app.post("/usuarios/registrar")
async def registrar_usuario(user: UserCreate):
    global user_id_counter
    
    for existing_user in users_db.values():
        if existing_user['username'] == user.username:
            raise HTTPException(status_code=400, detail="Usuário já existe")
    
    hashed_password = bcrypt.hashpw(user.password.encode('utf-8'), bcrypt.gensalt())
    
    user_data = {
        'id': user_id_counter,
        'username': user.username,
        'password_hash': hashed_password.decode('utf-8')
    }
    
    users_db[user_id_counter] = user_data
    user_id_counter += 1
    
    USER_REGISTRATIONS.inc()
    
    return {"id": user_data['id'], "username": user_data['username'], "message": "Usuário criado com sucesso"}

@app.post("/usuarios/login")
async def login_usuario(login: UserLogin):
    user = None
    for user_data in users_db.values():
        if user_data['username'] == login.username:
            user = user_data
            break
    
    if not user:
        USER_LOGINS.labels(status='user_not_found').inc()
        raise HTTPException(status_code=401, detail="Credenciais inválidas")
    
    if bcrypt.checkpw(login.password.encode('utf-8'), user['password_hash'].encode('utf-8')):
        USER_LOGINS.labels(status='success').inc()
        return {"message": "Login bem-sucedido", "user_id": user['id']}
    else:
        USER_LOGINS.labels(status='invalid_password').inc()
        raise HTTPException(status_code=401, detail="Credenciais inválidas")

@app.get("/usuarios/{user_id}")
async def get_usuario(user_id: int):
    user = users_db.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuário não encontrado")
    
    return {"id": user['id'], "username": user['username']}

@app.get("/health")
async def health():
    return {"status": "healthy"}

@app.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)