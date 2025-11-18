#!/bin/bash
#*************************
# KEDA Load Test Runner - Automatizado
# Configura ambiente Python e executa teste de carga
#*************************

echo "🚀 KEDA Load Test - Setup Automatizado"
echo "======================================"

# Ir para diretório do projeto
cd /home/luiz7/amazon-eks-scaling-with-keda-and-karpenter

# Verificar se estamos no diretório correto
if [[ ! -f "app/keda/keda-mock-sqs-post.py" ]]; then
    echo "❌ Arquivo de teste não encontrado!"
    echo "📍 Certifique-se de estar no diretório correto do projeto"
    exit 1
fi

echo "📍 Diretório: $(pwd)"
echo "✅ Script de teste encontrado: app/keda/keda-mock-sqs-post.py"

# Carregar variáveis de ambiente
source deployment/environmentVariables.sh

echo ""
echo "🔍 Verificação Pré-Teste:"
echo "========================"
echo "🏗️ Cluster: $CLUSTER_NAME"
echo "📨 SQS Queue: $SQS_QUEUE_NAME"
echo "💾 DynamoDB: $DYNAMODB_TABLE"

# Verificar se cluster está acessível
echo -n "🔗 Conectividade cluster: "
if kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    echo "⚠️ Cluster não acessível. Verifique conectividade!"
    exit 1
fi

# Verificar nodes
NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
echo "🖥️ Nodes ativos: $NODES"

# Verificar KEDA
KEDA_PODS=$(kubectl get pods -n keda --no-headers 2>/dev/null | grep Running | wc -l)
echo "🔧 KEDA pods: $KEDA_PODS/3"

# Verificar aplicação
APP_PODS=$(kubectl get pods -n keda-test --no-headers 2>/dev/null | grep Running | wc -l)
echo "📦 App pods: $APP_PODS"

# Verificar HPA
HPA_COUNT=$(kubectl get hpa -n keda-test --no-headers 2>/dev/null | wc -l)
echo "📈 HPA ativo: $HPA_COUNT"

echo ""
if [[ $NODES -eq 0 || $KEDA_PODS -lt 3 || $APP_PODS -eq 0 || $HPA_COUNT -eq 0 ]]; then
    echo "⚠️ Sistema não está completamente pronto!"
    echo "💡 Execute './restore-production-state.sh' primeiro"
    
    read -p "🤔 Continuar mesmo assim? (y/N): " continue_anyway
    if [[ $continue_anyway != "y" && $continue_anyway != "Y" ]]; then
        echo "❌ Teste cancelado"
        exit 1
    fi
fi

echo "🐍 Configurando Ambiente Python..."
echo "=================================="

# Ir para diretório app/keda
cd app/keda

# Verificar se ambiente virtual já existe
if [[ -d "env" ]]; then
    echo "♻️ Ambiente virtual já existe, reutilizando..."
else
    echo "📦 Criando ambiente virtual..."
    python3 -m venv env
    
    if [[ ! -d "env" ]]; then
        echo "❌ Erro ao criar ambiente virtual!"
        exit 1
    fi
    echo "✅ Ambiente virtual criado"
fi

# Ativar ambiente virtual
echo "🔌 Ativando ambiente virtual..."
source env/bin/activate

# Verificar se ativação funcionou
if [[ "$VIRTUAL_ENV" == "" ]]; then
    echo "❌ Erro ao ativar ambiente virtual!"
    exit 1
fi
echo "✅ Ambiente virtual ativo: $VIRTUAL_ENV"

# Verificar se boto3 está instalado
echo "📚 Verificando dependências..."
if python3 -c "import boto3" 2>/dev/null; then
    echo "✅ boto3 já instalado"
else
    echo "📥 Instalando boto3..."
    pip install boto3
    
    # Verificar instalação
    if python3 -c "import boto3" 2>/dev/null; then
        echo "✅ boto3 instalado com sucesso"
    else
        echo "❌ Erro ao instalar boto3!"
        exit 1
    fi
fi

echo ""
echo "🎯 Verificação Final:"
echo "===================="
echo "✅ Ambiente Python configurado"
echo "✅ boto3 disponível"
echo "✅ Script de teste pronto"

# Mostrar informações sobre SQS atual
echo ""
echo "📊 Status Atual SQS:"
CURRENT_MESSAGES=$(aws sqs get-queue-attributes --queue-url "$SQS_QUEUE_URL" --attribute-names ApproximateNumberOfMessages --region "$AWS_REGION" --query 'Attributes.ApproximateNumberOfMessages' --output text 2>/dev/null || echo "N/A")
echo "   • Mensagens na fila: $CURRENT_MESSAGES"

echo ""
echo "🚀 PRONTO PARA TESTE!"
echo "===================="
echo ""
echo "📋 Opções de Execução:"
echo "1) 🧪 Teste Rápido (30 segundos - 1 processo)"
echo "2) 🔥 Teste Médio (2 minutos - 2 processos paralelos)" 
echo "3) 💥 MEGA TESTE - Como ontem! (4 processos paralelos)"
echo "4) 🎛️ Teste Personalizado (escolha duração e processos)"
echo "5) 📈 Só Monitorar (sem enviar mensagens)"
echo "0) 🚪 Sair"

read -p "Escolha uma opção (0-5): " test_option

case $test_option in
    1)
        echo "🧪 Iniciando Teste Rápido (30s - 1 processo)..."
        timeout 30 python3 keda-mock-sqs-post.py
        ;;
    2)
        echo "🔥 Iniciando Teste Médio (2min - 2 processos paralelos)..."
        echo "🚀 Executando 2 processos simultaneamente..."
        timeout 120 python3 keda-mock-sqs-post.py &
        timeout 120 python3 keda-mock-sqs-post.py &
        wait
        ;;
    3)
        echo "💥💥💥 MEGA TESTE - COMO ONTEM! 💥💥💥"
        echo "🚀 Executando 4 processos simultaneamente..."
        echo "⚡ SEM TIMEOUT - igual ao seu teste manual de ontem!"
        echo ""
        read -p "⚠️ Tem certeza? Vai consumir muitos recursos! (y/N): " confirm
        if [[ $confirm == "y" || $confirm == "Y" ]]; then
            echo "🔥🔥🔥 INICIANDO BOMBARDEIO SQS! 🔥🔥🔥"
            echo "🎯 4 processos paralelos SEM LIMITE DE TEMPO..."
            echo "⚠️ VOCÊ PRECISARÁ PARAR MANUALMENTE (Ctrl+C)"
            echo ""
            
            # Criar arquivo para controlar os processos
            echo $$ > /tmp/keda_test_parent.pid
            
            python3 keda-mock-sqs-post.py &
            echo "🚀 Processo 1/4 iniciado (PID: $!)"
            echo $! >> /tmp/keda_test_pids.txt
            
            python3 keda-mock-sqs-post.py &
            echo "🚀 Processo 2/4 iniciado (PID: $!)"
            echo $! >> /tmp/keda_test_pids.txt
            
            python3 keda-mock-sqs-post.py &
            echo "🚀 Processo 3/4 iniciado (PID: $!)"
            echo $! >> /tmp/keda_test_pids.txt
            
            python3 keda-mock-sqs-post.py &
            echo "🚀 Processo 4/4 iniciado (PID: $!)"
            echo $! >> /tmp/keda_test_pids.txt
            
            echo ""
            echo "⚡ TODOS OS PROCESSOS INICIADOS!"
            echo "📊 Monitore em outro terminal: ./monitor-test.sh"
            echo ""
            echo "⏰ Deixe rodar até chegar a 200+ pods e 6 nodes"
            echo "🛑 Para parar: Pressione Ctrl+C ou execute:"
            echo "   kill \$(cat /tmp/keda_test_pids.txt)"
            echo ""
            
            # Interceptar Ctrl+C para cleanup
            trap 'echo -e "\n\n🛑 Parando todos os processos..."; kill $(cat /tmp/keda_test_pids.txt 2>/dev/null) 2>/dev/null; rm -f /tmp/keda_test_*.txt 2>/dev/null; echo "✅ Processos finalizados!"; exit 0' INT
            
            wait
            
            # Cleanup no final normal
            rm -f /tmp/keda_test_*.txt 2>/dev/null
        else
            echo "❌ Teste cancelado"
            exit 0
        fi
        ;;
    4)
        read -p "⏱️ Digite duração em segundos: " duration
        read -p "🔄 Digite número de processos paralelos (1-8): " processes
        
        if [[ $processes -gt 8 ]]; then
            echo "⚠️ Limitando a 8 processos para segurança"
            processes=8
        fi
        
        echo "🎛️ Iniciando Teste Personalizado (${duration}s, ${processes} processos)..."
        
        for i in $(seq 1 $processes); do
            timeout $duration python3 keda-mock-sqs-post.py &
            echo "🚀 Processo $i/$processes iniciado"
        done
        
        wait
        ;;
    5)
        echo "📈 Modo Monitoramento - Pressione Ctrl+C para parar"
        echo "🔍 Abrindo terminal de monitoramento..."
        echo ""
        echo "📊 Comandos úteis para monitorar:"
        echo "   kubectl get hpa -n keda-test -w"
        echo "   kubectl get pods -n keda-test -w"
        echo "   kubectl get nodes -w"
        echo ""
        # Não executar o script, só mostrar comandos
        exit 0
        ;;
    0)
        echo "👋 Saindo..."
        exit 0
        ;;
    *)
        echo "❌ Opção inválida!"
        exit 1
        ;;
esac

echo ""
echo "⏱️ Teste finalizado!"
echo "==================="

# Mostrar estatísticas finais
echo "📊 Estatísticas Finais:"
FINAL_MESSAGES=$(aws sqs get-queue-attributes --queue-url "$SQS_QUEUE_URL" --attribute-names ApproximateNumberOfMessages --region "$AWS_REGION" --query 'Attributes.ApproximateNumberOfMessages' --output text 2>/dev/null || echo "N/A")
echo "   • Mensagens na fila: $FINAL_MESSAGES"

echo "   • Pods ativos:"
kubectl get pods -n keda-test --no-headers | grep Running | wc -l

echo "   • Nodes ativos:"
kubectl get nodes --no-headers | wc -l

echo ""
echo "💡 Para monitorar resultados:"
echo "   kubectl get hpa -n keda-test"
echo "   kubectl get pods -n keda-test"
echo "   kubectl get nodes"

echo ""
echo "🎉 Teste concluído com sucesso!"