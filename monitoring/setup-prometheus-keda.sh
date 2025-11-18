#!/bin/bash
#*************************
# SETUP PROMETHEUS + GRAFANA para KEDA Metrics
# Instalação completa de stack de monitoramento
#*************************

source /home/luiz7/amazon-eks-scaling-with-keda-and-karpenter/deployment/environmentVariables.sh

echo "📊 KEDA + Prometheus Integration Setup"
echo "====================================="

echo "🚨 IMPORTANTE: Este script irá instalar:"
echo "   • Prometheus Operator"
echo "   • Grafana"
echo "   • ServiceMonitor para KEDA"
echo "   • Métricas customizadas de exemplo"
echo ""

read -p "⚠️ Tem certeza que o estado atual está salvo? (Y/n): " confirm
if [[ $confirm != "Y" ]]; then
    echo "❌ Execute primeiro o backup do estado atual!"
    exit 1
fi

# 1. Adicionar repositório Helm do Prometheus
echo "📦 Adicionando repositório Helm do Prometheus..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. Criar namespace para monitoring
echo "🏗️ Criando namespace monitoring..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# 3. Instalar Prometheus Operator (kube-prometheus-stack)
echo "🔧 Instalando Prometheus + Grafana..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
    --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
    --set grafana.adminPassword=admin123 \
    --set prometheus.service.type=NodePort \
    --set grafana.service.type=NodePort

# 4. Aguardar deployments
echo "⏳ Aguardando Prometheus e Grafana ficarem prontos..."
kubectl wait --for=condition=available deployment/prometheus-kube-prometheus-prometheus-operator -n monitoring --timeout=300s
kubectl wait --for=condition=available deployment/prometheus-grafana -n monitoring --timeout=300s

# 5. Habilitar métricas no KEDA
echo "📊 Habilitando métricas Prometheus no KEDA..."
kubectl patch deployment keda-operator -n keda -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"8080","prometheus.io/path":"/metrics"}}}}}'

kubectl patch deployment keda-operator-metrics-apiserver -n keda -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"8080","prometheus.io/path":"/metrics"}}}}}'

# 6. Criar ServiceMonitor para KEDA
echo "🎯 Criando ServiceMonitor para KEDA..."
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: keda-operator
  namespace: monitoring
  labels:
    app: keda-operator
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: keda-operator
  namespaceSelector:
    matchNames:
    - keda
  endpoints:
  - port: metricsservice
    path: /metrics
    interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: keda-metrics-apiserver
  namespace: monitoring
  labels:
    app: keda-metrics-apiserver
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: keda-operator-metrics-apiserver
  namespaceSelector:
    matchNames:
    - keda
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
EOF

# 7. Criar aplicação de exemplo com métricas Prometheus
echo "🚀 Criando aplicação de exemplo com métricas..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-app
  namespace: ${SQS_TARGET_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: metrics-app
  template:
    metadata:
      labels:
        app: metrics-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: metrics-app
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        - containerPort: 8080
          name: metrics
        command: ["/bin/sh"]
        args:
        - -c
        - |
          # Criar servidor de métricas simples
          cat > /tmp/metrics.sh << 'METRICS_EOF'
          #!/bin/sh
          while true; do
            REQUESTS=\$(shuf -i 10-200 -n 1)
            LATENCY=\$(echo "scale=3; \$(shuf -i 100-2000 -n 1)/1000" | bc -l || echo "0.5")
            ERROR_RATE=\$(echo "scale=3; \$(shuf -i 0-10 -n 1)/100" | bc -l || echo "0.01")
            
            cat << EOF | nc -l -p 8080 -q 1
          HTTP/1.1 200 OK
          Content-Type: text/plain
          
          # HELP http_requests_total Total HTTP requests
          # TYPE http_requests_total counter
          http_requests_total{job="metrics-app",method="GET",status="200"} \$REQUESTS
          http_requests_total{job="metrics-app",method="GET",status="500"} \$(echo "\$REQUESTS * \$ERROR_RATE" | bc -l | cut -d. -f1)
          
          # HELP http_request_duration_seconds HTTP request latency
          # TYPE http_request_duration_seconds histogram
          http_request_duration_seconds_bucket{job="metrics-app",le="0.1"} \$(echo "\$REQUESTS * 0.3" | bc -l | cut -d. -f1)
          http_request_duration_seconds_bucket{job="metrics-app",le="0.5"} \$(echo "\$REQUESTS * 0.7" | bc -l | cut -d. -f1)
          http_request_duration_seconds_bucket{job="metrics-app",le="1.0"} \$(echo "\$REQUESTS * 0.9" | bc -l | cut -d. -f1)
          http_request_duration_seconds_bucket{job="metrics-app",le="+Inf"} \$REQUESTS
          http_request_duration_seconds_sum{job="metrics-app"} \$(echo "\$REQUESTS * \$LATENCY" | bc -l)
          http_request_duration_seconds_count{job="metrics-app"} \$REQUESTS
          
          # HELP active_connections Current active connections
          # TYPE active_connections gauge
          active_connections{job="metrics-app"} \$(shuf -i 1-100 -n 1)
          EOF
          done
          METRICS_EOF
          
          chmod +x /tmp/metrics.sh
          
          # Instalar bc e netcat
          apk add --no-cache bc netcat-openbsd
          
          # Iniciar nginx e servidor de métricas
          nginx -g 'daemon off;' &
          /tmp/metrics.sh
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: metrics-app-service
  namespace: ${SQS_TARGET_NAMESPACE}
  labels:
    app: metrics-app
spec:
  selector:
    app: metrics-app
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: metrics
    port: 8080
    targetPort: 8080
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: metrics-app
  namespace: monitoring
  labels:
    app: metrics-app
spec:
  selector:
    matchLabels:
      app: metrics-app
  namespaceSelector:
    matchNames:
    - ${SQS_TARGET_NAMESPACE}
  endpoints:
  - port: metrics
    path: /metrics
    interval: 15s
EOF

# 8. Obter URLs de acesso
echo ""
echo "⏳ Aguardando serviços ficarem prontos..."
sleep 30

PROMETHEUS_PORT=$(kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
GRAFANA_PORT=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')

echo ""
echo "🎉 INSTALAÇÃO CONCLUÍDA!"
echo "========================"
echo ""
echo "📊 URLs de Acesso:"
echo "   🔍 Prometheus: http://${NODE_IP}:${PROMETHEUS_PORT}"
echo "   📈 Grafana: http://${NODE_IP}:${GRAFANA_PORT}"
echo "       User: admin"
echo "       Pass: admin123"
echo ""
echo "🎯 Métricas Disponíveis:"
echo "   • http_requests_total - Total de requests HTTP"
echo "   • http_request_duration_seconds - Latência das requisições"
echo "   • active_connections - Conexões ativas"
echo "   • keda_* - Métricas internas do KEDA"
echo ""
echo "📋 Próximos Passos:"
echo "   1. Acesse o Grafana e importe dashboards"
echo "   2. Verifique as métricas no Prometheus"
echo "   3. Crie ScaledObjects baseados em Prometheus"
echo ""
echo "💡 Exemplo de query Prometheus:"
echo '   rate(http_requests_total[5m])'
echo ""
echo "🔧 Para usar com KEDA:"
echo "   Veja examples em presentation-kit/advanced-metrics-demo.sh"