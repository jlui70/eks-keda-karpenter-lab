#!/bin/bash
#*************************
# KEDA Test Monitor - Monitoramento em Tempo Real
# Acompanha escalabilidade durante os testes
#*************************

echo "📊 KEDA Test Monitor - Monitoramento em Tempo Real"
echo "=================================================="

cd /home/luiz7/amazon-eks-scaling-with-keda-and-karpenter
source deployment/environmentVariables.sh

echo "🎯 Monitorando: $CLUSTER_NAME"
echo "📨 SQS Queue: $SQS_QUEUE_NAME"
echo "📈 Pressione Ctrl+C para parar"
echo ""

# Função para mostrar status
show_status() {
    local timestamp=$(date '+%H:%M:%S')
    
    # SQS Messages
    local sqs_messages=$(aws sqs get-queue-attributes \
        --queue-url "$SQS_QUEUE_URL" \
        --attribute-names ApproximateNumberOfMessages \
        --region "$AWS_REGION" \
        --query 'Attributes.ApproximateNumberOfMessages' \
        --output text 2>/dev/null || echo "N/A")
    
    # Pods
    local pods=$(kubectl get pods -n keda-test --no-headers 2>/dev/null | grep -E "(Running|Pending|ContainerCreating)" | wc -l)
    local running_pods=$(kubectl get pods -n keda-test --no-headers 2>/dev/null | grep Running | wc -l)
    local pending_pods=$(kubectl get pods -n keda-test --no-headers 2>/dev/null | grep -E "(Pending|ContainerCreating)" | wc -l)
    
    # Nodes
    local nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep Ready | wc -l)
    
    # HPA Target
    local hpa_target=$(kubectl get hpa -n keda-test --no-headers 2>/dev/null | awk '{print $3}' | head -1)
    
    # Clear screen and show updated info
    clear
    echo "📊 KEDA Test Monitor - $timestamp"
    echo "============================================"
    echo ""
    echo "📨 SQS Messages: $sqs_messages"
    echo "📦 Pods: $pods total ($running_pods running, $pending_pods pending)"
    echo "🖥️ Nodes: $nodes total ($ready_nodes ready)"
    echo "📈 HPA Target: $hpa_target"
    echo ""
    echo "🔄 Atualização automática a cada 5 segundos..."
    echo "⏹️ Pressione Ctrl+C para parar"
    echo ""
    
    # Mostrar detalhes dos pods se houver muitos
    if [[ $pods -gt 5 ]]; then
        echo "📋 Status Detalhado dos Pods:"
        kubectl get pods -n keda-test --no-headers 2>/dev/null | \
            awk '{print $1, $3}' | \
            sort | uniq -c | \
            while read count name status; do
                echo "   $status: $count pods"
            done
        echo ""
    fi
    
    # Mostrar pods individuais se forem poucos
    if [[ $pods -le 5 && $pods -gt 0 ]]; then
        echo "📋 Pods Individuais:"
        kubectl get pods -n keda-test --no-headers 2>/dev/null | \
            awk '{printf "   %-30s %s\n", $1, $3}'
        echo ""
    fi
    
    # Mostrar nodes
    if [[ $nodes -gt 0 ]]; then
        echo "🖥️ Nodes:"
        kubectl get nodes --no-headers 2>/dev/null | \
            awk '{printf "   %-35s %s\n", $1, $2}'
        echo ""
    fi
    
    # Mostrar últimos eventos importantes
    echo "📋 Últimos Eventos (1 min):"
    kubectl get events -n keda-test --sort-by='.lastTimestamp' 2>/dev/null | \
        tail -3 | \
        while IFS= read -r line; do
            if [[ -n "$line" && "$line" != "No resources found"* ]]; then
                echo "   $(echo "$line" | awk '{print $1, $2, $3, $4}' | cut -c1-70)"
            fi
        done
    echo ""
}

# Interceptar Ctrl+C
trap 'echo -e "\n\n🛑 Monitoramento parado pelo usuário"; exit 0' INT

# Loop principal de monitoramento
while true; do
    show_status
    sleep 5
done