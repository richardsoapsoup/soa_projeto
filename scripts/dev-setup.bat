@echo off
echo Configurando ambiente de desenvolvimento...

echo Verificando Docker...
docker --version
if %errorlevel% neq 0 (
    echo Docker nao encontrado. Instale o Docker Desktop primeiro.
    pause
    exit /b 1
)

echo Verificando Docker Compose...
docker-compose --version
if %errorlevel% neq 0 (
    echo Docker Compose nao encontrado.
    pause
    exit /b 1
)

echo Verificando Kubernetes...
kubectl version --client
if %errorlevel% neq 0 (
    echo kubectl nao encontrado. Instale o Kubernetes.
)

echo Criando diretorios necessarios...
if not exist logs mkdir logs
if not exist data mkdir data

echo Configurando permissoes...
icacls logs /grant:r "Todos:(F)" /T >nul 2>&1
icacls data /grant:r "Todos:(F)" /T >nul 2>&1

echo.
echo Ambiente configurado!
echo.
pause