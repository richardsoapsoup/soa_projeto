@echo off
echo Limpeza completa do ambiente...

echo Parando containers...
docker-compose down

echo Removendo containers parados...
docker container prune -f

echo Removendo imagens nao utilizadas...
docker image prune -f

echo Removendo volumes nao utilizados...
docker volume prune -f

echo Removendo networks nao utilizadas...
docker network prune -f

echo Limpando diretorios temporarios...
if exist logs rmdir /s /q logs
if exist data rmdir /s /q data
mkdir logs
mkdir data

echo.
echo Limpeza completa!
echo Execute start-complete.bat para reiniciar.
pause