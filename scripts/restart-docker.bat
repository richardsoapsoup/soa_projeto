@echo off
echo Reiniciando servicos...
call scripts/stop-docker.bat
timeout 5
call scripts/start-docker.bat