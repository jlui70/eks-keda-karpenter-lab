# 💰 Análise Detalhada de Custos - EKS KEDA Karpenter

## 📊 Visão Geral

Este documento fornece uma análise **completa e transparente** dos custos associados à execução deste lab na AWS.

> ⚠️ **IMPORTANTE:** Os custos podem variar dependendo da região AWS, tipo de instância e duração de uso.

---

## 💵 Tabela de Custos Detalhada

### Cenário 1: Cluster 24/7 (Uso Contínuo)

| Recurso | Quantidade | Custo/Hora | Custo/Dia | Custo/Mês | Notas |
|---------|------------|------------|-----------|-----------|-------|
| **EKS Control Plane** | 1 | $0.10 | $2.40 | $72.00 | Fixo, não varia |
| **NAT Gateway** | 3 | $0.135 | $3.24 | $97.20 | $0.045/hora cada |
| **EC2 m5.xlarge** | 2 | $0.192 | $4.61 | $138.24 | Mínimo (nodegroup inicial) |
| **EC2 m5.2xlarge** | 0-3 | $0.384 | $0-$27.65 | $0-$829.44 | Karpenter (sob demanda) |
| **EBS gp3** | 100 GB | $0.014 | $0.33 | $10.00 | $0.08/GB/mês |
| **Application Load Balancer** | 1 | $0.025 | $0.60 | $18.00 | Se usado |
| **SQS FIFO** | - | - | < $0.10 | < $1.00 | Pay per request |
| **DynamoDB On-Demand** | - | - | < $0.10 | < $1.00 | Pay per request |
| **ECR Storage** | 1 GB | - | - | < $1.00 | Primeiros 500MB grátis |
| **Data Transfer** | 10 GB | - | $0.16 | $5.00 | Dentro da região |
| **CloudWatch Logs** | 5 GB | - | $0.10 | $2.50 | $0.50/GB |
| | | | **TOTAL/DIA** | **TOTAL/MÊS** | |
| | | | **~$11-12** | **~$345-380** | Sem picos de tráfego |

### Cenário 2: Lab de Estudo (2-3 horas)

| Recurso | Custo | Notas |
|---------|-------|-------|
| **EKS Control Plane** | $0.30 | 3h × $0.10/h |
| **NAT Gateway (3x)** | $0.40 | 3h × $0.135/h |
| **EC2 Instances** | $0.50-1.00 | Varia com teste |
| **EBS Volumes** | $0.05 | Proporcional |
| **SQS + DynamoDB** | < $0.01 | Pay per request |
| **Data Transfer** | < $0.10 | Mínimo |
| **TOTAL** | **$1.25-2.00** | 💚 Muito acessível! |

---

## 📉 Breakdown por Componente

### 1️⃣ Amazon EKS Control Plane

```
Custo: $0.10/hora = $72/mês
Tipo: FIXO (não varia)
```

- **Impossível reduzir** - É o custo do serviço gerenciado
- Mesmo com cluster vazio, você paga $0.10/hora
- **Dica:** Delete o cluster quando não estiver usando

### 2️⃣ NAT Gateways

```
Custo: $0.045/hora cada × 3 = $0.135/hora = $97.20/mês
Tipo: FIXO por quantidade
```

**Por que 3 NAT Gateways?**
- Alta disponibilidade (1 por Availability Zone)
- Arquitetura production-ready

**💡 Como reduzir:**

```bash
# Opção 1: Usar apenas 1 NAT Gateway (DEV/LAB)
# Edite deployment/cluster/createCluster.sh antes de criar

# Opção 2: Remover NAT Gateways (nodes públicos)
# ⚠️ Não recomendado para produção
```

**Economia:** $64.80/mês usando 1 NAT ao invés de 3

### 3️⃣ EC2 Instances (Nodes)

#### Nodegroup Inicial (Fixo)

| Tipo | vCPU | RAM | Custo/Hora | Custo/Mês |
|------|------|-----|------------|-----------|
| m5.xlarge | 4 | 16 GB | $0.192 | $138.24 |
| m5.2xlarge | 8 | 32 GB | $0.384 | $276.48 |

**Configuração padrão:**
- 2× m5.xlarge (nodegroup inicial) = $276.48/mês

#### Karpenter Nodes (Dinâmicos)

```
Provisionados SOB DEMANDA durante testes
Custo proporcional ao tempo de uso
```

**Exemplo de teste SQS:**
- 3× m5.2xlarge provisionados
- Duração: 15 minutos
- Custo: 3 × $0.384 × 0.25h = **$0.29**

**💡 Como reduzir:**

1. **Use Spot Instances com Karpenter**

```yaml
# deployment/karpenter/nodepool.yaml
spec:
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["spot"]  # ← Mude de "on-demand"
```

**Economia:** Até 70% nos custos de EC2

2. **Limite CPU máximo**

```yaml
spec:
  limits:
    cpu: 32  # ← Limite máximo de vCPUs
```

### 4️⃣ Elastic Block Storage (EBS)

```
Custo: $0.08/GB/mês (gp3)
Volume típico: 100 GB = $8-10/mês
```

**💡 Dica:** Volumes são deletados automaticamente com os nodes

### 5️⃣ Application Load Balancer (Opcional)

```
Custo: $0.025/hora = $18/mês
+ $0.008/LCU-hora (Load Balancer Capacity Units)
```

**Quando é criado:**
- Se você configurar Ingress para aplicações HTTP

**💡 Como evitar:**
- Use NodePort ou Port-Forward para testes

### 6️⃣ SQS FIFO Queue

```
Custo: Pay per request
- $0.50 por 1M de requisições (padrão)
- $0.70 por 1M de requisições (FIFO)
```

**Exemplo de teste com 10.000 mensagens:**
- Enviar: 10.000 × $0.0000007 = $0.007
- Receber: 10.000 × $0.0000007 = $0.007
- **Total:** < $0.02

### 7️⃣ DynamoDB

```
Custo: On-Demand (Pay per request)
- $1.25 por 1M de Write Request Units
- $0.25 por 1M de Read Request Units
```

**Exemplo de teste:**
- 10.000 writes (pagamentos salvos)
- Custo: 10.000 × $0.00000125 = **$0.0125**

### 8️⃣ Elastic Container Registry (ECR)

```
Custo: $0.10/GB/mês
Primeiros 500 MB: GRÁTIS
```

**Imagens deste projeto:**
- keda-sqs-reader: ~150 MB
- **Custo:** $0 (dentro do free tier)

### 9️⃣ Data Transfer

```
Dentro da mesma região: $0.01/GB
Entre regiões: $0.02/GB
Para internet: $0.09/GB
```

**Tráfego típico do lab:** < 10 GB = **$0.10**

### 🔟 CloudWatch Logs

```
Custo: $0.50/GB ingerido
Armazenamento: $0.03/GB/mês
```

**Logs deste projeto:**
- EKS control plane: ~1 GB/dia
- Aplicações: ~1 GB/dia
- **Total:** ~$2.50/mês

---

## 💡 Estratégias para MINIMIZAR Custos

### 🎯 1. Use o Lab APENAS Quando Necessário

**Melhor prática: Crie e Delete**

```bash
# Sexta-feira: Cria o lab
sh deployment/_main.sh

# Faz todos os testes (2-3 horas)
sh tests/run-load-test.sh
sh tests/load-test-http-scaling.sh

# Sexta-feira: Deleta TUDO
sh scripts/cleanup.sh

# Custo: $1.25-2.00 ✅
```

**vs Deixar rodando o fim de semana:**
- Custo: $11/dia × 2 dias = **$22** ❌

### 🎯 2. Reduza NAT Gateways (DEV/LAB)

**Antes de criar o cluster**, edite `deployment/cluster/createCluster.sh`:

```bash
# Opção original (3 NAT Gateways)
eksctl create cluster \
  --name ${CLUSTER_NAME} \
  --region ${AWS_REGION} \
  ...

# Opção econômica (1 NAT Gateway)
eksctl create cluster \
  --name ${CLUSTER_NAME} \
  --region ${AWS_REGION} \
  --vpc-nat-mode Single \  # ← Adicione esta linha
  ...
```

**Economia:** $64.80/mês

### 🎯 3. Configure Karpenter para Spot Instances

**Edite:** `deployment/karpenter/nodepool.yaml`

```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]  # ← Mude aqui
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ["m5.xlarge", "m5.2xlarge", "m5a.xlarge"]  # ← Adicione tipos alternativos
```

**Economia:** Até 70% nos custos de EC2

**⚠️ Trade-off:** Spot instances podem ser interrompidas com 2 min de aviso

### 🎯 4. Configure AWS Budget Alerts

**Evite surpresas!**

```bash
# Criar budget de $10
aws budgets create-budget \
  --account-id $ACCOUNT_ID \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

**budget.json:**
```json
{
  "BudgetName": "EKS-Lab-Budget",
  "BudgetLimit": {
    "Amount": "10",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
```

### 🎯 5. Use AWS Free Tier Quando Possível

**Serviços com Free Tier relevantes:**
- ❌ EKS: Não tem free tier
- ✅ EC2: 750 horas/mês (t2.micro/t3.micro) - Não aplicável para este lab
- ✅ ECR: 500 MB storage grátis
- ✅ DynamoDB: 25 GB storage + 25 WCUs/25 RCUs
- ✅ SQS: 1M de requisições grátis/mês

### 🎯 6. Monitore Custos em Tempo Real

**AWS Cost Explorer:**
```bash
# Ver custos dos últimos 7 dias
aws ce get-cost-and-usage \
  --time-period Start=2024-11-10,End=2024-11-17 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

**💡 Configure alertas no CloudWatch**

---

## 📊 Comparação de Cenários

| Cenário | Duração | Configuração | Custo | Ideal Para |
|---------|---------|--------------|-------|------------|
| **Lab Rápido** | 2-3h | Default, delete após | $1.25-2 | ✅ Aprendizado |
| **Lab Weekend** | 48h | Default, delete após | $22-24 | Exploração |
| **Dev Ativo** | 1 mês | 1 NAT, Spot instances | $180-200 | Desenvolvimento |
| **Produção** | 1 mês | 3 NATs, On-demand | $345-380 | ❌ Não recomendado (demo only) |

---

## ⚠️ ALERTAS IMPORTANTES

### 🚨 Recursos que CONTINUAM cobrando mesmo IDLE

1. **EKS Control Plane** → $0.10/hora (SEMPRE)
2. **NAT Gateways** → $0.045/hora cada (SEMPRE)
3. **EC2 Nodegroup** → $0.192/hora por node (SEMPRE)
4. **EBS Volumes** → $0.08/GB/mês (SEMPRE)

**📍 Conclusão:** Se o cluster existe, você paga. **DELETE após uso!**

### 🚨 Custos "Escondidos" a Observar

1. **Data Transfer OUT para internet**
   - Se expor serviços publicamente
   - Pode adicionar $0.09/GB

2. **CloudWatch Logs**
   - Logs verbosos podem gerar muitos GB
   - Configure retenção: 7 dias

3. **Application Load Balancers**
   - $18/mês base + LCU charges
   - Use NodePort para dev

4. **Elastic IPs não associados**
   - $0.005/hora se não estiver em uso
   - Liberados automaticamente com `eksctl delete`

---

## 📋 Checklist de Economia

Antes de criar o lab:

- [ ] Li este documento de custos
- [ ] Configurei AWS Budget Alert para $10
- [ ] Decidi se vou usar 1 ou 3 NAT Gateways
- [ ] Configurei Karpenter para Spot (se aplicável)
- [ ] Tenho calendário para **deletar recursos em 2-3 horas**

Durante o lab:

- [ ] Monitoro custos no AWS Cost Explorer
- [ ] Verifico que apenas recursos necessários estão ativos
- [ ] Testo rapidamente para não estender o tempo

Após o lab:

- [ ] **Executei `scripts/cleanup.sh`** ✅
- [ ] Verifiquei no Console AWS que TUDO foi deletado
- [ ] Confirmei no Cost Explorer que não há cobranças inesperadas
- [ ] Guardei logs/screenshots para referência futura

---

## 🎓 Resumo Executivo

### ✅ Para Estudar/Aprender (2-3 horas):

```
Custo: $1.25 - $2.00
Estratégia: Crie → Teste → Delete
ROI: EXCELENTE (conhecimento valioso por < $2)
```

### ⚠️ Para Deixar Rodando 24/7:

```
Custo: $345-380/mês
Estratégia: NÃO RECOMENDADO (este é um lab de demonstração)
Melhor: Use ambiente serverless ou otimize arquitetura
```

### 💡 Recomendação Final:

> **Trate este lab como descartável:** Crie quando precisar, use por poucas horas, delete completamente. Repita sempre que quiser estudar. Custos serão SEMPRE < $2 por sessão.

---

## 📞 Tem Dúvidas sobre Custos?

- Consulte [AWS Pricing Calculator](https://calculator.aws/)
- Veja [AWS Cost Management](https://aws.amazon.com/aws-cost-management/)

---

<p align="center">
  <strong>💰 Economize inteligentemente, aprenda eficientemente! 💡</strong>
</p>
