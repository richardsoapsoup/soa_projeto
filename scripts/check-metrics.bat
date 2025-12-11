@echo off
echo Verificando metricas disponiveis...

echo.
echo 1. Metricas de servicos:
curl -s "http://localhost:9090/api/v1/label/job/values" | python -c "
import json, sys
data = json.load(sys.stdin)
print('Jobs monitorados:')
for job in data['data']:
    print(f'  {job}')
"

echo.
echo 2. Metricas personalizadas:
for metric in requests_total user_registrations_total post_creations_total request_latency_seconds_count; do (
    echo Verificando %metric%...
    curl -s "http://localhost:9090/api/v1/query?query=%metric%" | python -c "
import json, sys
data = json.load(sys.stdin)
if data['data']['result']:
    print(f'  {metric} - OK')
else:
    print(f'  {metric} - Nao encontrado')
" 2>nul
)
done

echo.
echo 3. Health checks:
curl -s "http://localhost:9090/api/v1/query?query=up" | python -c "
import json, sys
data = json.load(sys.stdin)
print('Status dos servicos:')
for result in data['data']['result']:
    job = result['metric'].get('job', 'unknown')
    instance = result['metric'].get('instance', 'unknown')
    value = result['value'][1]
    status = '✓ UP' if value == '1' else '✗ DOWN'
    print(f'  {status} {job} ({instance})')
"

echo.
echo Verificacao de metricas concluida!