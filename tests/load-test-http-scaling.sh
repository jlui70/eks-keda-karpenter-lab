#!/bin/bash

# 🚀 Script de Teste de Carga HTTP para KEDA Autoscaling
# Testa autoscaling do ecommerce-ui baseado em requisições HTTP

set -e

URL="http://eks.devopsproject.com.br/"
NAMESPACE="ecommerce"

echo "======================================"
echo "🚀 KEDA HTTP AUTOSCALING - LOAD TEST"
echo "======================================"
echo ""
echo "Target: $URL"
echo "Namespace: $NAMESPACE"
echo "HTTPScaledObject: ecommerce-ui-http-scaler"
echo "Min Replicas: 2 | Max Replicas: 20"
echo "Target: 100 pending requests per pod"
echo ""

# Função para mostrar status dos pods
show_pods() {
    echo ""
    echo "📊 Current Pods:"
    kubectl get pods -n $NAMESPACE -l app=ecommerce-ui --no-headers | wc -l | xargs echo "  Total pods:"
    echo ""
}

# Função para mostrar HPA
show_hpa() {
    echo "📈 HPA Status:"
    kubectl get hpa -n $NAMESPACE keda-hpa-ecommerce-ui-http-scaler
    echo ""
}

# Estado inicial
echo "🔍 Estado INICIAL:"
show_pods
show_hpa

echo "======================================"
echo "⏳ Aguardando 10 segundos antes de iniciar..."
echo "======================================"
sleep 10

# Teste 1: Carga Baixa (warmup)
echo ""
echo "======================================"
echo "🟢 TESTE 1: Carga BAIXA (Warmup)"
echo "======================================"
echo "Threads: 2, Connections: 50, Duration: 30s"
echo ""
wrk -t 2 -c 50 -d 30s --timeout 10s $URL

show_pods
show_hpa

echo "⏳ Aguardando 30 segundos..."
sleep 30

# Teste 2: Carga Moderada
echo ""
echo "======================================"
echo "🟡 TESTE 2: Carga MODERADA"
echo "======================================"
echo "Threads: 4, Connections: 200, Duration: 60s"
echo ""
wrk -t 4 -c 200 -d 60s --timeout 10s $URL

show_pods
show_hpa

echo "⏳ Aguardando 30 segundos..."
sleep 30

# Teste 3: Carga Alta
echo ""
echo "======================================"
echo "🔴 TESTE 3: Carga ALTA"
echo "======================================"
echo "Threads: 8, Connections: 500, Duration: 90s"
echo ""
wrk -t 8 -c 500 -d 90s --timeout 10s $URL

show_pods
show_hpa

echo "⏳ Aguardando 60 segundos..."
sleep 60

# Teste 4: Spike Test
echo ""
echo "======================================"
echo "⚡ TESTE 4: SPIKE TEST (Pico Extremo)"
echo "======================================"
echo "Threads: 10, Connections: 1000, Duration: 60s"
echo ""
wrk -t 10 -c 1000 -d 60s --timeout 10s $URL

show_pods
show_hpa

# Estado final
echo ""
echo "======================================"
echo "🏁 TESTE FINALIZADO"
echo "======================================"
echo ""
echo "⏳ Aguardando 5 minutos para scale down..."
echo "(ScaledownPeriod configurado: 300s)"
echo ""

for i in {1..10}; do
    echo "🕐 Tempo: $((i*30))s"
    sleep 30
    show_pods
done

echo ""
echo "======================================"
echo "✅ TESTE COMPLETO"
echo "======================================"
echo ""
echo "📊 Status final:"
show_pods
show_hpa

echo ""
echo "🎯 Próximo passo:"
echo "1. Verificar dashboard Grafana: http://grafana.devopsproject.com.br/"
echo "2. Ver gráfico 'E-Commerce Pods Count' (deve mostrar picos)"
echo "3. Ver 'CPU/Memory' (deve ter aumentado durante teste)"
echo ""
