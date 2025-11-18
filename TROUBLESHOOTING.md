# 🔧 Troubleshooting - EKS KEDA Karpenter

## 🎯 Objetivo

Este guia cobre os problemas mais comuns encontrados durante a instalação e operação deste lab, com soluções práticas e testadas.

---

## 📑 Índice

1. [Problemas no Deployment Inicial](#1-problemas-no-deployment-inicial)
2. [Problemas com KEDA](#2-problemas-com-keda)
3. [Problemas com Karpenter](#3-problemas-com-karpenter)
4. [Problemas de Rede](#4-problemas-de-rede)
5. [Problemas com Monitoramento](#5-problemas-com-monitoramento)
6. [Problemas durante Testes](#6-problemas-durante-testes)
7. [Problemas de Permissões IAM](#7-problemas-de-permissões-iam)
8. [Comandos Úteis de Diagnóstico](#8-comandos-úteis-de-diagnóstico)

---

## 1. Problemas no Deployment Inicial

### ❌ Problema: `eksctl create cluster` falha

**Sintomas:**
```bash
Error: creating CloudFormation stack failed
```

**Causas possíveis:**
1. Quotas de VPC/EIP atingidas
2. Região sem capacidade para tipo de instância
3. Credenciais AWS inválidas
4. Falta de permissões IAM

**Soluções:**

```bash
# 1. Verificar credenciais
aws sts get-caller-identity
# Deve retornar Account, UserId, Arn

# 2. Verificar quotas de VPC
aws service-quotas get-service-quota \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --region us-east-1

# 3. Verificar permissões IAM
aws iam get-user
# Usuário deve ter permissões de EKS, EC2, VPC, IAM

# 4. Tentar região alternativa
export AWS_REGION="us-west-2"
# Edite deployment/environmentVariables.sh

# 5. Verificar logs detalhados
eksctl create cluster --config-file=cluster.yaml --verbose 4
```

**Solução alternativa:**
```bash
# Deletar stacks órfãos
aws cloudformation delete-stack \
  --stack-name eksctl-eks-demo-scale-cluster \
  --region us-east-1

# Aguardar conclusão
aws cloudformation wait stack-delete-complete \
  --stack-name eksctl-eks-demo-scale-cluster \
  --region us-east-1

# Tentar novamente
sh deployment/_main.sh
```

---

### ❌ Problema: Cluster cria mas `kubectl` não conecta

**Sintomas:**
```bash
$ kubectl get nodes
error: You must be logged in to the server (Unauthorized)
```

**Solução:**

```bash
# Atualizar kubeconfig
aws eks update-kubeconfig \
  --name eks-demo-scale \
  --region us-east-1

# Verificar contexto
kubectl config current-context
# Deve retornar: arn:aws:eks:us-east-1:123456:cluster/eks-demo-scale

# Testar conexão
kubectl get nodes
```

---

## 2. Problemas com KEDA

### ❌ Problema: KEDA não escala pods (ficam em 1 réplica)

**Sintomas:**
- Mensagens acumulando na fila SQS
- Pods não aumentam mesmo com carga
- `kubectl get hpa` mostra `<unknown>` em TARGETS

**Diagnóstico:**

```bash
# 1. Verificar se KEDA está rodando
kubectl get pods -n keda
# Todos devem estar Running

# 2. Verificar ScaledObject
kubectl get scaledobject -n keda-test
kubectl describe scaledobject sqs-scaledobject -n keda-test

# 3. Ver logs do KEDA operator
kubectl logs -n keda -l app=keda-operator --tail=50

# 4. Verificar HPA criado pelo KEDA
kubectl get hpa -n keda-test
kubectl describe hpa keda-hpa-sqs-scaledobject -n keda-test
```

**Causas comuns:**

#### Causa 1: Falta de permissões IAM

**Sintoma no log:**
```
AccessDenied: User: arn:aws:sts::123456:assumed-role/...
is not authorized to perform: sqs:GetQueueAttributes
```

**Solução:**

```bash
# Verificar IAM role associada ao Service Account
kubectl describe sa keda-service-account -n keda-test
# Deve ter annotation: eks.amazonaws.com/role-arn

# Verificar se role existe
aws iam get-role --role-name keda-demo-role

# Recriar IRSA se necessário
cd deployment/keda
sh createkeda.sh
```

#### Causa 2: URL da fila incorreta

**Solução:**

```bash
# Obter URL correta
SQS_URL=$(aws sqs get-queue-url \
  --queue-name keda-demo-queue.fifo \
  --region us-east-1 \
  --query 'QueueUrl' \
  --output text)

echo $SQS_URL

# Editar ScaledObject
kubectl edit scaledobject sqs-scaledobject -n keda-test
# Corrigir queueURL na seção triggers
```

#### Causa 3: Métricas não são coletadas

**Solução:**

```bash
# Verificar se metrics server do KEDA está expondo métricas
kubectl get apiservice v1beta1.external.metrics.k8s.io
# STATUS deve ser True

# Verificar logs do metrics server
kubectl logs -n keda -l app=keda-metrics-apiserver

# Reiniciar KEDA se necessário
kubectl rollout restart deployment keda-operator -n keda
kubectl rollout restart deployment keda-metrics-apiserver -n keda
```

---

### ❌ Problema: Pods escalam mas não processam mensagens

**Sintomas:**
- Pods em estado `Running`
- Mensagens permanecem na fila
- Logs do pod mostram erros de conexão

**Diagnóstico:**

```bash
# Ver logs de um pod
kubectl logs -n keda-test -l app=sqs-app --tail=50

# Entrar no pod para debug
kubectl exec -it -n keda-test <pod-name> -- /bin/bash
# Testar conexão com SQS
python3 -c "import boto3; sqs = boto3.client('sqs', region_name='us-east-1'); print(sqs.list_queues())"
```

**Soluções:**

```bash
# 1. Verificar se Service Account está associado ao pod
kubectl describe pod -n keda-test <pod-name> | grep "Service Account"

# 2. Verificar variáveis de ambiente
kubectl exec -n keda-test <pod-name> -- env | grep -E "AWS|SQS"

# 3. Verificar se pod tem network para internet (via NAT Gateway)
kubectl exec -n keda-test <pod-name> -- curl -I https://sqs.us-east-1.amazonaws.com

# 4. Recriar deployment
kubectl delete deployment sqs-app -n keda-test
kubectl apply -f deployment/app/keda-python-app.yaml
```

---

## 3. Problemas com Karpenter

### ❌ Problema: Karpenter não provisiona nodes (pods em Pending)

**Sintomas:**
```bash
$ kubectl get pods -n keda-test
NAME              READY   STATUS    RESTARTS   AGE
sqs-app-xxx       0/1     Pending   0          5m
sqs-app-yyy       0/1     Pending   0          5m
```

**Diagnóstico:**

```bash
# 1. Verificar se Karpenter está rodando
kubectl get pods -n karpenter
# Deve estar Running

# 2. Ver logs do Karpenter
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100

# 3. Verificar NodePool
kubectl get nodepool
kubectl describe nodepool default

# 4. Verificar se há pending pods
kubectl get pods -n keda-test -o wide
```

**Causas comuns:**

#### Causa 1: Tags de discovery incorretas

**Sintoma no log do Karpenter:**
```
ERROR   unable to resolve subnets   {"error": "no subnets found"}
```

**Solução:**

```bash
# Verificar se subnets têm a tag correta
aws ec2 describe-subnets \
  --filters "Name=tag:karpenter.sh/discovery,Values=eks-demo-scale" \
  --query 'Subnets[*].SubnetId' \
  --region us-east-1

# Se não retornar nada, as tags estão faltando
# Recriar cluster com tags corretas:
eksctl delete cluster --name eks-demo-scale --region us-east-1
sh deployment/cluster/createCluster.sh
```

#### Causa 2: Limites de CPU atingidos no NodePool

**Solução:**

```bash
# Verificar limite atual
kubectl get nodepool default -o yaml | grep -A5 limits

# Aumentar limite se necessário
kubectl edit nodepool default
# Editar spec.limits.cpu para valor maior (ex: 1000)
```

#### Causa 3: Sem permissões IAM para Karpenter

**Solução:**

```bash
# Verificar IAM role do Karpenter
kubectl describe sa karpenter -n karpenter
# Deve ter annotation com role ARN

# Verificar se role existe
aws iam get-role --role-name KarpenterControllerRole-eks-demo-scale

# Recriar Karpenter se necessário
cd deployment/karpenter
sh createkarpenter.sh
```

---

### ❌ Problema: Nodes criados mas pods não são agendados neles

**Sintomas:**
- `kubectl get nodes` mostra novos nodes
- Pods continuam em `Pending`

**Diagnóstico:**

```bash
# Verificar status do node
kubectl describe node <node-name>

# Verificar taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# Ver eventos do scheduler
kubectl get events -n keda-test --sort-by='.lastTimestamp'
```

**Solução:**

```bash
# Se node tiver taint "NotReady"
# Aguardar 1-2 minutos (node está inicializando)

# Se persistir, verificar CNI
kubectl get pods -n kube-system -l k8s-app=aws-node
# Todos devem estar Running

# Reiniciar daemonset do CNI se necessário
kubectl rollout restart daemonset aws-node -n kube-system
```

---

## 4. Problemas de Rede

### ❌ Problema: Pods não conseguem acessar internet/SQS

**Sintomas:**
```python
botocore.exceptions.EndpointConnectionError: 
Could not connect to the endpoint URL: https://sqs.us-east-1.amazonaws.com/
```

**Diagnóstico:**

```bash
# Testar DNS
kubectl exec -n keda-test <pod-name> -- nslookup sqs.us-east-1.amazonaws.com

# Testar conectividade
kubectl exec -n keda-test <pod-name> -- curl -I https://sqs.us-east-1.amazonaws.com
```

**Causas comuns:**

#### Causa 1: NAT Gateway não configurado

**Solução:**

```bash
# Verificar se NAT Gateways existem
aws ec2 describe-nat-gateways \
  --filter "Name=tag:alpha.eksctl.io/cluster-name,Values=eks-demo-scale" \
  --region us-east-1

# Se não existirem, recriar cluster com NAT habilitado
# (padrão do eksctl já cria)
```

#### Causa 2: Security Group bloqueando tráfego

**Solução:**

```bash
# Verificar Security Group dos nodes
SG_ID=$(aws eks describe-cluster \
  --name eks-demo-scale \
  --region us-east-1 \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text)

# Ver regras
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --region us-east-1

# Adicionar regra de saída se necessário (normalmente já existe)
aws ec2 authorize-security-group-egress \
  --group-id $SG_ID \
  --protocol all \
  --cidr 0.0.0.0/0 \
  --region us-east-1
```

---

## 5. Problemas com Monitoramento

### ❌ Problema: Grafana não está acessível

**Sintomas:**
- `kubectl get ingress` não retorna nada
- URL do Grafana não responde

**Solução:**

```bash
# Opção 1: Port-forward temporário
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-grafana 3000:80
# Acesse: http://localhost:3000

# Opção 2: Obter LoadBalancer (se configurado)
kubectl get svc -n monitoring

# Opção 3: Criar NodePort
kubectl patch svc kube-prometheus-stack-grafana -n monitoring \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/type", "value":"NodePort"}]'

# Obter porta
kubectl get svc kube-prometheus-stack-grafana -n monitoring
# Acesse: http://<node-ip>:<node-port>
```

---

### ❌ Problema: Dashboards Grafana sem dados

**Sintomas:**
- Dashboards carregam mas gráficos estão vazios
- "No data" em todos os painéis

**Diagnóstico:**

```bash
# Verificar se Prometheus está coletando métricas
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-prometheus 9090:9090
# Acesse: http://localhost:9090
# Vá em Status → Targets

# Verificar ServiceMonitor
kubectl get servicemonitor -n monitoring

# Ver logs do Prometheus
kubectl logs -n monitoring \
  -l app.kubernetes.io/name=prometheus \
  --tail=50
```

**Solução:**

```bash
# Recriar ServiceMonitor
kubectl delete servicemonitor servicemonitor-ecommerce -n monitoring
kubectl apply -f monitoring/servicemonitor-ecommerce.yaml

# Reiniciar Prometheus
kubectl delete pod -n monitoring \
  -l app.kubernetes.io/name=prometheus
```

---

## 6. Problemas durante Testes

### ❌ Problema: Script de teste falha ao enviar mensagens

**Sintomas:**
```bash
$ sh tests/run-load-test.sh
botocore.exceptions.NoCredentialsError: Unable to locate credentials
```

**Solução:**

```bash
# Configurar credenciais AWS na máquina local
aws configure

# Ou exportar temporariamente
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"

# Verificar
aws sts get-caller-identity

# Executar teste novamente
sh tests/run-load-test.sh
```

---

### ❌ Problema: Scaling é muito lento

**Sintomas:**
- Leva > 5 minutos para escalar de 1 → 50 pods

**Diagnóstico:**

```bash
# Verificar configuração do ScaledObject
kubectl get scaledobject sqs-scaledobject -n keda-test -o yaml

# Ver eventos
kubectl get events -n keda-test --sort-by='.lastTimestamp'
```

**Otimização:**

```bash
# Aplicar ScaledObject otimizado
kubectl apply -f deployment/keda/scaledobject-fast-scaledown.yaml

# Configurações que aceleram:
# - pollingInterval: 10 (verificar a cada 10s)
# - cooldownPeriod: 60 (scale-down mais rápido)
# - queueLength: 2 (menos mensagens por pod)
```

---

## 7. Problemas de Permissões IAM

### ❌ Problema: `AccessDenied` ao acessar SQS/DynamoDB

**Sintomas:**
```
botocore.exceptions.ClientError: An error occurred (AccessDenied) 
when calling the ReceiveMessage operation
```

**Diagnóstico:**

```bash
# Verificar Service Account
kubectl describe sa keda-service-account -n keda-test

# Deve mostrar:
# Annotations: eks.amazonaws.com/role-arn: arn:aws:iam::123456:role/keda-demo-role

# Verificar se role existe
aws iam get-role --role-name keda-demo-role

# Verificar policies anexadas
aws iam list-attached-role-policies --role-name keda-demo-role
```

**Solução:**

```bash
# Recriar IRSA
cd deployment/keda
sh createkeda.sh

# Ou criar manualmente
eksctl create iamserviceaccount \
  --name keda-service-account \
  --namespace keda-test \
  --cluster eks-demo-scale \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess \
  --approve \
  --override-existing-serviceaccounts

# Reiniciar pods
kubectl rollout restart deployment sqs-app -n keda-test
```

---

## 8. Comandos Úteis de Diagnóstico

### 🔍 Verificação Geral do Cluster

```bash
# Ver todos os nodes
kubectl get nodes -o wide

# Ver todos os pods em todos namespaces
kubectl get pods -A

# Ver eventos recentes
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Uso de recursos
kubectl top nodes
kubectl top pods -A
```

### 🔍 KEDA Específico

```bash
# Ver todos ScaledObjects
kubectl get scaledobject -A

# Ver HPA gerenciado pelo KEDA
kubectl get hpa -A

# Logs do KEDA operator
kubectl logs -n keda -l app=keda-operator -f

# Logs do metrics server
kubectl logs -n keda -l app=keda-metrics-apiserver -f
```

### 🔍 Karpenter Específico

```bash
# Ver NodePools
kubectl get nodepool

# Ver nodes provisionados pelo Karpenter
kubectl get nodes -l karpenter.sh/provisioner-name=default

# Logs do Karpenter
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f

# Métricas do Karpenter
kubectl port-forward -n karpenter svc/karpenter 8000:8000
# Acesse: http://localhost:8000/metrics
```

### 🔍 Aplicação e Fila

```bash
# Mensagens na fila SQS
aws sqs get-queue-attributes \
  --queue-url <QUEUE_URL> \
  --attribute-names ApproximateNumberOfMessages \
  --region us-east-1

# Itens no DynamoDB
aws dynamodb scan \
  --table-name payments \
  --select COUNT \
  --region us-east-1

# Logs da aplicação
kubectl logs -n keda-test -l app=sqs-app --tail=100 -f
```

---

## 🆘 Ainda com Problemas?

Se nenhuma solução acima funcionou:

### 1. Coleta de Informações

Execute este script para coletar informações de debug:

```bash
#!/bin/bash
echo "=== CLUSTER INFO ===" > debug-info.txt
kubectl cluster-info >> debug-info.txt

echo "\n=== NODES ===" >> debug-info.txt
kubectl get nodes -o wide >> debug-info.txt

echo "\n=== PODS ===" >> debug-info.txt
kubectl get pods -A >> debug-info.txt

echo "\n=== KEDA ===" >> debug-info.txt
kubectl get scaledobject -A >> debug-info.txt
kubectl logs -n keda -l app=keda-operator --tail=100 >> debug-info.txt

echo "\n=== KARPENTER ===" >> debug-info.txt
kubectl get nodepool >> debug-info.txt
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100 >> debug-info.txt

echo "\n=== EVENTS ===" >> debug-info.txt
kubectl get events -A --sort-by='.lastTimestamp' | tail -50 >> debug-info.txt

cat debug-info.txt
```

### 2. Abra uma Issue

- Vá para [GitHub Issues](https://github.com/jlui70/eks-keda-karpenter-lab/issues)
- Anexe o arquivo `debug-info.txt`
- Descreva o problema em detalhes
- Inclua passos para reproduzir

### 3. Recursos da Comunidade

- [KEDA Community](https://keda.sh/community/)
- [Karpenter Slack](https://kubernetes.slack.com/archives/C02SFFZSA2K)
- [AWS re:Post](https://repost.aws/)

---

<p align="center">
  <strong>🔧 A maioria dos problemas tem solução simples - não desista! 💪</strong>
</p>
