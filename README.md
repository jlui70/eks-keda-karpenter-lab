# 🚀 EKS Autoscaling com KEDA e Karpenter

<p align="center">
  <img src="img/aws_kedakarpenter_arch_small.gif" alt="Arquitetura EKS KEDA Karpenter" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/AWS-EKS-orange?style=for-the-badge&logo=amazon-aws" />
  <img src="https://img.shields.io/badge/KEDA-2.x-blue?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Karpenter-0.32-green?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Kubernetes-1.28-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white" />
  <img src="https://img.shields.io/badge/Python-3.12-3776AB?style=for-the-badge&logo=python&logoColor=white" />
</p>

> **Lab completo de autoscaling inteligente no Kubernetes usando AWS EKS, KEDA e Karpenter**

---

## 📖 Sobre o Projeto

Este projeto demonstra **autoscaling avançado no Kubernetes** em dois cenários práticos do mundo real:

### 🎯 Cenários de Demonstração

1. **📊 Processamento de Filas SQS**
   - Escala automática de **1 → 50+ pods** baseado no número de mensagens
   - KEDA monitora fila SQS FIFO em tempo real
   - Karpenter provisiona novos nós em **60-90 segundos**
   - Processamento de pagamentos com persistência no DynamoDB

2. **🛍️ Tráfego HTTP - Simulação Black Friday**
   - Escala de **2 → 40 pods** conforme tráfego HTTP aumenta
   - KEDA HTTP Add-on intercepta e mede requisições por segundo (RPS)
   - Scale-down inteligente quando tráfego diminui
   - Monitoramento em tempo real via Grafana

### 🎬 Vídeos das Demos

- 📹 **[Demo 1: SQS Scaling](https://www.youtube.com/seu-video-1)** - Processamento de 10.000 mensagens
- 📹 **[Demo 2: HTTP Black Friday](https://www.youtube.com/seu-video-2)** - Simulação de pico de tráfego
- 📹 **[Apresentação Completa](https://www.youtube.com/seu-video-3)** - Walkthrough do lab completo

> 💡 **Nota:** Adicione os links dos seus vídeos do YouTube acima

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (us-east-1)                   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Amazon EKS Cluster                     │  │
│  │                                                           │  │
│  │  ┌──────────────┐      ┌────────────────────────────┐   │  │
│  │  │   KEDA       │◄────►│  ScaledObject (SQS)        │   │  │
│  │  │  Controller  │      │  - queueLength: 2          │   │  │
│  │  └──────────────┘      │  - maxReplicas: 2000       │   │  │
│  │         │              └────────────────────────────┘   │  │
│  │         ▼                                                │  │
│  │  ┌──────────────────────────────────────────┐           │  │
│  │  │  sqs-app Deployment (Pods)               │           │  │
│  │  │  • Processa mensagens SQS                │           │  │
│  │  │  • Salva no DynamoDB                     │           │  │
│  │  └──────────────────────────────────────────┘           │  │
│  │                                                           │  │
│  │  ┌──────────────┐      ┌────────────────────────────┐   │  │
│  │  │  Karpenter   │◄────►│  NodePool                  │   │  │
│  │  │  Controller  │      │  - m5.xlarge, m5.2xlarge   │   │  │
│  │  └──────────────┘      │  - On-Demand instances     │   │  │
│  │         │              └────────────────────────────┘   │  │
│  │         ▼                                                │  │
│  │  ┌──────────────────────────────────────────┐           │  │
│  │  │  EC2 Nodes (Auto-provisionados)          │           │  │
│  │  │  • Scale-up: 60-90s                      │           │  │
│  │  │  • Scale-down: Quando subutilizado       │           │  │
│  │  └──────────────────────────────────────────┘           │  │
│  │                                                           │  │
│  │  ┌──────────────────────────────────────────┐           │  │
│  │  │  Prometheus + Grafana                    │           │  │
│  │  │  • Dashboards customizados               │           │  │
│  │  │  • Métricas em tempo real                │           │  │
│  │  └──────────────────────────────────────────┘           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌────────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │  SQS FIFO      │  │  DynamoDB    │  │  ECR             │   │
│  │  Queue         │  │  (payments)  │  │  (Docker Images) │   │
│  └────────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 🔧 Componentes Principais

| Componente | Versão | Função |
|------------|--------|--------|
| **AWS EKS** | 1.28 | Cluster Kubernetes gerenciado |
| **KEDA** | 2.x | Event-driven autoscaling (suporta 60+ scalers) |
| **Karpenter** | 0.32 | Node autoscaling inteligente |
| **Prometheus** | Latest | Coleta de métricas |
| **Grafana** | Latest | Visualização de dashboards |
| **SQS FIFO** | - | Fila de mensagens (garante ordem) |
| **DynamoDB** | - | Armazenamento NoSQL (PAY_PER_REQUEST) |
| **ECR** | - | Registry de imagens Docker |

---

## 💰 Custos Estimados

### 📊 Análise Detalhada

| Recurso | Custo/mês (24/7) | Custo Lab (2-3h) | Notas |
|---------|------------------|------------------|-------|
| **EKS Control Plane** | $72.00 | $0.30 | $0.10/hora |
| **NAT Gateways (3x)** | $96.00 | $0.40 | $0.045/hora cada |
| **EC2 Nodes** | ~$200.00 | $0.50 | Varia com quantidade/tipo |
| **EBS Volumes** | ~$10.00 | $0.05 | gp3 storage |
| **SQS** | < $1.00 | < $0.01 | Pay per request |
| **DynamoDB** | < $1.00 | < $0.01 | On-demand pricing |
| **ECR** | < $1.00 | $0.00 | Primeiros 500MB grátis |
| **Data Transfer** | ~$5.00 | < $0.10 | Dentro da mesma região |
| **TOTAL** | **~$370/mês** | **~$1-2** | |

### 💡 Dicas para Economizar

1. **🎯 Use o lab apenas quando necessário**
   - Delete todos os recursos após concluir os testes
   - Use o script `scripts/cleanup.sh` para limpeza completa

2. **🌐 Reduza NAT Gateways (Opcional para DEV)**
   ```bash
   # Em vez de 3 NAT Gateways (um por AZ), use apenas 1
   # Edite deployment/cluster/createCluster.sh antes de criar o cluster
   ```

3. **💸 Configure Karpenter para usar Spot Instances**
   ```bash
   # Reduz custos de EC2 em até 70%
   # Adequado para workloads tolerantes a interrupções
   ```

4. **📊 Configure AWS Budget Alerts**
   ```bash
   aws budgets create-budget \
     --account-id $ACCOUNT_ID \
     --budget file://budget.json
   ```

⚠️ **IMPORTANTE:** Este lab custa apenas **$1-2** se você limpar os recursos em **2-3 horas**!

Para detalhes completos, veja [CUSTOS.md](CUSTOS.md)

---

## 🔧 Pré-requisitos

### 📋 Ferramentas Necessárias

Antes de começar, instale as seguintes ferramentas:

| Ferramenta | Versão Mínima | Verificar Instalação | Instalação |
|------------|---------------|----------------------|------------|
| **AWS CLI** | 2.x | `aws --version` | [Guia AWS](https://aws.amazon.com/cli/) |
| **kubectl** | 1.28+ | `kubectl version --client` | [Kubernetes Docs](https://kubernetes.io/docs/tasks/tools/) |
| **eksctl** | 0.150+ | `eksctl version` | [eksctl.io](https://eksctl.io/) |
| **Helm** | 3.x | `helm version` | [Helm Docs](https://helm.sh/docs/intro/install/) |
| **Docker** | 20.x+ | `docker --version` | [Docker Docs](https://docs.docker.com/get-docker/) |

### ☁️ Requisitos AWS

- **Conta AWS ativa** com créditos disponíveis
- **Credenciais AWS** configuradas localmente
- **Permissões IAM necessárias:**
  - EKS (criar/deletar clusters)
  - EC2 (criar instâncias, VPC, subnets, security groups)
  - SQS, DynamoDB, ECR
  - IAM (criar roles e policies)
  - CloudFormation

### 💻 Recursos Mínimos da Máquina Local

- **RAM:** 4 GB (8 GB recomendado)
- **Disco:** 10 GB livres
- **SO:** Linux, macOS, ou Windows (WSL2)

📚 **Guia completo de instalação:** [docs/01-prerequisitos.md](docs/01-prerequisitos.md)

---

## 🚀 Instalação Rápida

### 📦 1. Clone o Repositório

```bash
git clone https://github.com/jlui70/eks-keda-karpenter-lab.git
cd eks-keda-karpenter-lab
```

### 🔐 2. Configure Credenciais AWS

```bash
aws configure
# Insira:
# - AWS Access Key ID
# - AWS Secret Access Key  
# - Default region: us-east-1
# - Default output format: json

# Verifique
aws sts get-caller-identity
```

### ⚙️ 3. Ajuste Variáveis de Ambiente

```bash
cd deployment
nano environmentVariables.sh
```

Edite apenas se necessário (valores padrão funcionam):

```bash
export AWS_REGION="us-east-1"
export CLUSTER_NAME="eks-demo-scale"
export K8sversion="1.28"
export KARPENTER_VERSION=v0.32.0
export SQS_QUEUE_NAME="keda-demo-queue.fifo"
export DYNAMODB_TABLE="payments"
```

### 🏗️ 4. Execute o Deployment Automatizado

```bash
cd deployment
sh ./_main.sh
```

Você verá um menu interativo:

```
╔════════════════════════════════════════════════╗
║     EKS KEDA + Karpenter Deployment Menu      ║
╚════════════════════════════════════════════════╝

1) Deploy Tudo (Cluster + Karpenter + KEDA + Services)
2) Apenas Cluster EKS
3) Apenas Karpenter
4) Apenas KEDA
5) Apenas AWS Services (SQS + DynamoDB)
6) Sair

Escolha uma opção [1-6]:
```

**Escolha opção `1`** para deployment completo.

⏱️ **Tempo total:** ~20-25 minutos

📚 **Guia passo a passo detalhado:** [docs/02-instalacao-passo-a-passo.md](docs/02-instalacao-passo-a-passo.md)

---

## 🧪 Executando os Testes

### 📊 Teste 1: SQS Scaling

```bash
cd tests
./run-load-test.sh
```

**O que acontece:**
1. Script envia 10.000 mensagens para a fila SQS
2. KEDA detecta mensagens e escala pods (1 → 50+)
3. Karpenter provisiona novos nós automaticamente
4. Pods processam mensagens e salvam no DynamoDB
5. Scale-down automático quando fila esvazia

**Monitorar:**
- Terminal: métricas em tempo real
- Grafana: `http://<grafana-dns>` (veja [docs/05-monitoramento.md](docs/05-monitoramento.md))
- kubectl: `kubectl get pods -n keda-test -w`

### 🛍️ Teste 2: HTTP Black Friday

```bash
cd tests
./load-test-http-scaling.sh
```

**O que acontece:**
1. Simula tráfego HTTP crescente (Black Friday)
2. KEDA HTTP Add-on mede RPS (requests/second)
3. Escala de 2 → 40 pods conforme tráfego aumenta
4. Karpenter adiciona nós conforme necessário
5. Scale-down gradual quando tráfego diminui

📚 **Guia completo de testes:** [docs/06-testes-scaling.md](docs/06-testes-scaling.md)

---

## 📊 Monitoramento

### 🎨 Dashboards Grafana

O projeto inclui **2 dashboards customizados**:

1. **SQS Payments Dashboard**
   - Mensagens processadas em tempo real
   - Número de pods ativos
   - Utilização de CPU/Memória
   - Taxa de processamento (msgs/s)

2. **EKS E-commerce Dashboard**
   - HTTP requests por segundo
   - Latência de resposta
   - Pods scaling timeline
   - Nodes provisionados

### 📍 Acessar Grafana

```bash
# Obter URL do Grafana
kubectl get ingress -n monitoring

# Credenciais padrão
# User: admin
# Password: (obtido via comando abaixo)
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode && echo
```

📚 **Guia completo de monitoramento:** [docs/05-monitoramento.md](docs/05-monitoramento.md)

---

## 🗂️ Estrutura do Projeto

```
eks-keda-karpenter-lab/
│
├── 📄 README.md                    # Este arquivo
├── 📄 ARCHITECTURE.md              # Arquitetura detalhada
├── 📄 TROUBLESHOOTING.md           # Problemas comuns e soluções
├── 📄 CUSTOS.md                    # Análise de custos detalhada
├── 📄 LICENSE                      # Licença do projeto
├── 📄 .gitignore                   # Arquivos ignorados
│
├── 📁 app/                         # Aplicações Python
│   ├── keda/
│   │   ├── Dockerfile              # Imagem da aplicação SQS
│   │   ├── sqs-reader.py           # Processa mensagens SQS
│   │   └── keda-mock-sqs-post.py   # Script de teste (envia mensagens)
│   │
│   └── karpenter/
│       ├── Dockerfile
│       ├── karpenter-sqs-reader.py
│       └── karpenter-mock-sqs-post.py
│
├── 📁 deployment/                  # Scripts de deployment
│   ├── environmentVariables.sh     # Variáveis de ambiente
│   ├── _main.sh                    # Menu principal de deployment
│   │
│   ├── cluster/
│   │   └── createCluster.sh        # Cria cluster EKS
│   │
│   ├── karpenter/
│   │   ├── README.md
│   │   ├── cloudformation.yaml     # Template CloudFormation
│   │   └── createkarpenter.sh      # Instala Karpenter
│   │
│   ├── keda/
│   │   ├── README.md
│   │   ├── createkeda.sh           # Instala KEDA
│   │   ├── dynamoPolicy.json       # IAM policy para DynamoDB
│   │   ├── sqsPolicy.json          # IAM policy para SQS
│   │   ├── kedaScaleObject-video.yaml         # ScaledObject padrão
│   │   └── scaledobject-fast-scaledown.yaml   # ScaledObject otimizado
│   │
│   ├── app/
│   │   └── keda-python-app.yaml    # Deployment da aplicação
│   │
│   └── services/
│       └── awsService.sh           # Cria SQS + DynamoDB
│
├── 📁 monitoring/                  # Monitoramento
│   ├── README.md
│   ├── install-monitoring.sh       # Instala Prometheus + Grafana
│   ├── setup-prometheus-keda.sh    # Configura integração
│   ├── grafana-dashboard-sqs-payments.json
│   ├── grafana-dashboard-eks-ecommerce.json
│   └── servicemonitor-ecommerce.yaml
│
├── 📁 tests/                       # Scripts de teste
│   ├── README.md
│   ├── run-load-test.sh            # Teste SQS principal
│   ├── load-test-http-scaling.sh   # Teste HTTP
│   └── monitor-test.sh             # Monitor durante teste
│
├── 📁 scripts/                     # Utilitários
│   └── cleanup.sh                  # Limpa todos os recursos AWS
│
├── 📁 docs/                        # Documentação detalhada
│   ├── 01-prerequisitos.md
│   ├── 02-instalacao-passo-a-passo.md
│   ├── 03-configuracao-keda.md
│   ├── 04-configuracao-karpenter.md
│   ├── 05-monitoramento.md
│   ├── 06-testes-scaling.md
│   └── 07-limpeza-recursos.md
│
└── 📁 img/                         # Imagens e diagramas
    ├── architecture-diagram.png
    ├── Keda.gif
    └── aws_kedakarpenter_arch_small.gif
```

---

## 🐛 Troubleshooting

### Problema: Karpenter não provisiona nodes

**Sintomas:** Pods ficam em estado `Pending`

**Solução rápida:**
```bash
# Verificar logs do Karpenter
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

# Verificar NodePool
kubectl get nodepool -o yaml
```

### Problema: KEDA não escala pods

**Sintomas:** Mensagens na fila mas pods não aumentam

**Solução rápida:**
```bash
# Verificar ScaledObject
kubectl get scaledobject -n keda-test

# Ver logs do KEDA
kubectl logs -n keda -l app=keda-operator
```

### Problema: Grafana não está acessível

**Solução rápida:**
```bash
# Verificar se pod está rodando
kubectl get pods -n monitoring

# Criar port-forward temporário
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Acesse: http://localhost:3000
```

📚 **Troubleshooting completo:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

## 🧹 Limpeza de Recursos

⚠️ **IMPORTANTE:** Execute a limpeza para evitar custos desnecessários!

### 🚀 Opção 1: Script Automatizado (Recomendado)

```bash
cd scripts
./cleanup.sh
```

O script deleta automaticamente:
- ✅ Cluster EKS completo
- ✅ Todos os nós EC2
- ✅ VPC, subnets, NAT gateways
- ✅ SQS queue
- ✅ DynamoDB table
- ✅ ECR repositories
- ✅ IAM roles e policies
- ✅ CloudFormation stacks

⏱️ **Tempo:** ~10-15 minutos

### ⚙️ Opção 2: Manual

```bash
# 1. Deletar cluster (deleta tudo relacionado)
eksctl delete cluster --name eks-demo-scale --region us-east-1

# 2. Deletar SQS
aws sqs delete-queue --queue-url <SQS_QUEUE_URL> --region us-east-1

# 3. Deletar DynamoDB
aws dynamodb delete-table --table-name payments --region us-east-1

# 4. Deletar ECR repository
aws ecr delete-repository --repository-name keda-sqs-reader --force --region us-east-1
```

📚 **Guia completo:** [docs/07-limpeza-recursos.md](docs/07-limpeza-recursos.md)

---

## 🤝 Contribuindo

Contribuições são muito bem-vindas! 🎉

### Como Contribuir

1. **Fork** este repositório
2. Crie uma **branch** para sua feature (`git checkout -b feature/minha-feature`)
3. **Commit** suas mudanças (`git commit -m 'feat: adiciona nova feature'`)
4. **Push** para a branch (`git push origin feature/minha-feature`)
5. Abra um **Pull Request**

### 📝 Guidelines

- Scripts em bash devem ter tratamento de erros
- YAMLs devem ser validados antes do commit
- Documentação deve estar em português (PT-BR)
- Adicione testes quando aplicável

### 🐛 Reportar Bugs

Encontrou um bug? [Abra uma issue](https://github.com/jlui70/eks-keda-karpenter-lab/issues) com:
- Descrição do problema
- Passos para reproduzir
- Comportamento esperado vs atual
- Screenshots (se aplicável)

Veja detalhes em [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 📚 Documentação Adicional

### 📖 Guias Passo a Passo

- [Pré-requisitos e Instalação de Ferramentas](docs/01-prerequisitos.md)
- [Instalação Completa do Lab](docs/02-instalacao-passo-a-passo.md)
- [Configuração Detalhada do KEDA](docs/03-configuracao-keda.md)
- [Configuração Detalhada do Karpenter](docs/04-configuracao-karpenter.md)
- [Setup e Uso do Monitoramento](docs/05-monitoramento.md)
- [Executando e Entendendo os Testes](docs/06-testes-scaling.md)
- [Limpeza Completa de Recursos](docs/07-limpeza-recursos.md)

### 📄 Referências

- [Arquitetura Detalhada](ARCHITECTURE.md)
- [Análise de Custos Completa](CUSTOS.md)
- [Troubleshooting Avançado](TROUBLESHOOTING.md)
- [Guia de Contribuição](CONTRIBUTING.md)

### 🔗 Links Úteis

- [Documentação KEDA](https://keda.sh/)
- [Documentação Karpenter](https://karpenter.sh/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

## 📄 Licença

Este projeto está licenciado sob a **MIT License** - veja o arquivo [LICENSE](LICENSE) para detalhes.

---

## 🙏 Créditos e Agradecimentos

### 🌟 Projeto Base

Este projeto foi **baseado** no repositório [aws-samples/amazon-eks-scaling-with-keda-and-karpenter](https://github.com/jlui70/amazon-eks-scaling-with-keda-and-karpenter) criado pela AWS.

### ✨ Melhorias Implementadas

Esta versão inclui melhorias significativas:

- ✅ **Sistema de monitoramento completo** (Prometheus + Grafana)
- ✅ **2 dashboards Grafana customizados** para SQS e HTTP scaling
- ✅ **Scripts automatizados** de deploy, teste e limpeza
- ✅ **Documentação 100% em português (PT-BR)**
- ✅ **Guias passo a passo detalhados** para cada etapa
- ✅ **Troubleshooting abrangente** baseado em casos reais
- ✅ **Análise de custos detalhada** para evitar surpresas
- ✅ **Duas demos funcionais** (SQS + HTTP Black Friday)
- ✅ **Menu interativo** para facilitar deployment
- ✅ **Estrutura organizada** e pronta para produção

### 💙 Comunidade

Agradecimentos especiais à comunidade open-source de:
- **KEDA** - Event-driven autoscaling
- **Karpenter** - Node provisioning inteligente
- **Prometheus & Grafana** - Observabilidade
- **AWS** - Cloud infrastructure

---

## 📞 Contato e Suporte

### 💬 Precisa de Ajuda?

- 🐛 **Issues:** [GitHub Issues](https://github.com/jlui70/eks-keda-karpenter-lab/issues)
- 💡 **Discussões:** [GitHub Discussions](https://github.com/jlui70/eks-keda-karpenter-lab/discussions)

### 🌟 Gostou do Projeto?

Se este projeto foi útil para você:

- ⭐ Dê uma **estrela** no GitHub
- 🔄 **Compartilhe** com a comunidade
- 📹 **Inscreva-se** no canal do YouTube (link dos vídeos acima)
- 🤝 **Contribua** com melhorias

---

<p align="center">
  <strong>Desenvolvido com ❤️ para a comunidade brasileira de DevOps e Cloud</strong>
</p>

<p align="center">
  <sub>Última atualização: Novembro 2025</sub>
</p>
