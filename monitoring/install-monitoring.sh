#!/bin/bash

echo "📊 INSTALAÇÃO PROMETHEUS + GRAFANA STACK"
echo "========================================"

# Verificar se kubectl está configurado
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Erro: kubectl não está configurado ou cluster não está acessível"
    exit 1
fi

echo "✅ Cluster EKS conectado"

# Criar namespace para monitoring
echo ""
echo "📁 Criando namespace monitoring..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Instalar kube-prometheus-stack
echo ""
echo "🚀 Instalando Prometheus + Grafana via Helm..."
echo "   📦 Chart: kube-prometheus-stack"
echo "   📍 Namespace: monitoring"
echo "   ⏳ Aguarde, pode levar 2-3 minutos..."

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=10Gi \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.retention=15d \
  --set prometheus.prometheusSpec.scrapeInterval=30s \
  --set grafana.service.type=LoadBalancer \
  --wait --timeout=600s

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Prometheus + Grafana instalados com sucesso!"
    
    echo ""
    echo "📊 Status dos componentes:"
    kubectl get pods -n monitoring
    
    echo ""
    echo "🌐 Serviços disponíveis:"
    kubectl get svc -n monitoring
    
    echo ""
    echo "🎯 URLs de Acesso:"
    
    # Prometheus
    PROMETHEUS_SVC=$(kubectl get svc -n monitoring | grep prometheus-server || kubectl get svc -n monitoring | grep "prometheus.*prometheus")
    if [ ! -z "$PROMETHEUS_SVC" ]; then
        PROMETHEUS_PORT=$(kubectl get svc -n monitoring -o jsonpath='{.items[?(@.metadata.labels.app\.kubernetes\.io/name=="prometheus")].spec.ports[0].port}' 2>/dev/null || echo "9090")
        echo "   📈 Prometheus: kubectl port-forward svc/monitoring-kube-prometheus-prometheus $PROMETHEUS_PORT:9090 -n monitoring"
        echo "               Acesse: http://localhost:$PROMETHEUS_PORT"
    fi
    
    # Grafana
    GRAFANA_LB=$(kubectl get svc -n monitoring -l "app.kubernetes.io/name=grafana" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ ! -z "$GRAFANA_LB" ] && [ "$GRAFANA_LB" != "null" ]; then
        echo "   📊 Grafana LoadBalancer: http://$GRAFANA_LB"
    else
        echo "   📊 Grafana Port-Forward: kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring"
        echo "               Acesse: http://localhost:3000"
    fi
    
    echo "               Login: admin / admin123"
    
    echo ""
    echo "🎉 Stack de Monitoramento Pronto!"
    echo "📋 Próximos passos:"
    echo "   1. ✅ Prometheus coletando métricas do cluster"
    echo "   2. ✅ Grafana com dashboards pré-configurados"
    echo "   3. 🔄 Configurar ServiceMonitors para microserviços"
    echo "   4. 🎨 Dashboards customizados para e-commerce"
    
else
    echo "❌ Erro na instalação do Prometheus + Grafana"
    echo "📋 Verificar logs:"
    echo "   kubectl get events -n monitoring --sort-by='.lastTimestamp'"
    echo "   kubectl logs -l app.kubernetes.io/name=prometheus -n monitoring"
    exit 1
fi