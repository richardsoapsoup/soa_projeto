@echo off
echo Teste completo da API SOA...

echo.
echo 1. Verificando se servicos estao prontos...
call wait-for-services.bat

echo.
echo 2. Registrando usuario...
curl -X POST http://localhost:8000/usuarios/registrar ^
  -H "Content-Type: application/json" ^
  -d "{\"username\":\"john_doe\",\"password\":\"senha123\"}"

echo.
echo.
echo 3. Tentando registrar usuario duplicado...
curl -X POST http://localhost:8000/usuarios/registrar ^
  -H "Content-Type: application/json" ^
  -d "{\"username\":\"john_doe\",\"password\":\"outrasenha\"}"

echo.
echo.
echo 4. Fazendo login...
curl -X POST http://localhost:8000/usuarios/login ^
  -H "Content-Type: application/json" ^
  -d "{\"username\":\"john_doe\",\"password\":\"senha123\"}"

echo.
echo.
echo 5. Criando post...
curl -X POST http://localhost:8000/posts ^
  -H "Content-Type: application/json" ^
  -d "{\"text\":\"Meu primeiro post na API SOA\",\"user_id\":1}"

echo.
echo.
echo 6. Criando segundo post...
curl -X POST http://localhost:8000/posts ^
  -H "Content-Type: application/json" ^
  -d "{\"text\":\"Segundo post de teste\",\"user_id\":1}"

echo.
echo.
echo 7. Listando todos os posts...
curl http://localhost:8000/posts

echo.
echo.
echo 8. Buscando posts do usuario 1...
curl http://localhost:8000/usuarios/1/posts

echo.
echo.
echo 9. Verificando metricas...
curl -s http://localhost:8000/metrics | findstr /C:"requests_total" | findstr /V "#"

echo.
echo Teste completo concluido!
pause