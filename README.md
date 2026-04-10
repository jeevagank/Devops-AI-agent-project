.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.













































































  # Devops-AI-agent-project
Devops project with AI agents
# DevOps Multi-Agent AI System

An AI-powered system that generates a complete, production-grade AWS DevOps project from a single natural language prompt. Built using **AgentScope** multi-agent framework with **Llama 3.3 70B** (via Groq) as the AI backbone.

---

## What This Does

You type one prompt describing your project. The system spins up 10 specialized AI agents in sequence, each responsible for a specific DevOps domain, and generates a full project folder structure with all configuration files ready to review and deploy.

---

## Architecture

```
User Prompt
    ↓
Orchestrator (main.py)
    ↓
┌─────────────────────────────────────────────┐
│  TerraformAgent   → AWS Infrastructure IaC  │
│  DockerAgent      → Multi-stage Dockerfiles  │
│  K8sAgent         → Kubernetes Manifests     │
│  HelmAgent        → Helm Charts              │
│  JenkinsAgent     → CI/CD Pipeline           │
│  ArgoCDAgent      → GitOps Manifests         │
│  PrometheusAgent  → Monitoring & Alerts      │
│  GrafanaAgent     → Dashboard JSON           │
│  ELKAgent         → Centralized Logging      │
│  SecurityAgent    → Security Audit Report    │
└─────────────────────────────────────────────┘
    ↓
Complete Project Folder (85+ files)
```

---

## Generated Project Stack

This repo contains a generated DevOps project for a **production-grade AWS setup** with:

- **4 applications, 15 microservices** on Amazon EKS
- **3 AWS accounts** — dev, staging, prod
- **Aurora PostgreSQL** with Global DB and DR (primary: Sydney `ap-southeast-2`, DR: Singapore `ap-southeast-1`)
- **MSK Kafka** for async event streaming
- **ElastiCache Redis** for caching
- **ALB with WAF** for traffic management
- **Route53** for DNS
- **VPC** with private/public subnets and NAT gateway

---

## DevOps Tooling

| Tool | Purpose |
|------|---------|
| Terraform | Infrastructure as Code with module + env separation |
| Docker | Multi-stage Dockerfiles with non-root user |
| Kubernetes | Deployments, Services, Ingress, HPA, Network Policies |
| Helm | Charts per microservice with values separation |
| Jenkins | Multibranch CI/CD pipeline |
| ArgoCD | GitOps continuous delivery |
| Prometheus | Metrics scraping and alerting rules |
| Grafana | Custom dashboards for EKS, app, and DB metrics |
| ELK Stack | Filebeat + Logstash + Elasticsearch for centralized logging |

---

## Project Structure

```
output/
├── terraform/          # AWS infrastructure (VPC, EKS, Aurora, MSK, Redis, ALB, WAF)
├── docker/             # Dockerfiles per microservice
├── k8s/                # Kubernetes manifests
├── helm/               # Helm chart with templates
├── jenkins/            # Jenkinsfile
├── argocd/             # ArgoCD Application manifests
├── prometheus/         # Scrape configs and alerting rules
├── grafana/            # Dashboard JSON files
├── elk/                # Filebeat and Logstash configs
└── security_report.md  # Security audit report
```

---

## How to Run the Agent System

### Prerequisites
- Python 3.10+
- Groq API key (free at [console.groq.com](https://console.groq.com))

### Setup

```bash
git clone https://github.com/jeevagank/Devops-AI-agent-project.git
cd Devops-AI-agent-project
python3 -m venv venv
source venv/bin/activate
pip install agentscope
export GROQ_API_KEY="your-groq-api-key"
python3 main.py
```

### Example Prompt

```
Create a production-grade AWS DevOps project with 4 applications and 15 microservices 
deployed on EKS across 3 accounts (dev, staging, prod). Include Aurora PostgreSQL with 
Global DB and disaster recovery, MSK Kafka, ElastiCache Redis, ALB with WAF, Route53, 
Jenkins CI/CD, ArgoCD GitOps, Helm charts, Prometheus, Grafana, ELK stack, and full 
security best practices.
```

---

## Security Best Practices Implemented

- IAM least privilege roles
- No hardcoded credentials
- AWS Secrets Manager integration
- S3 encryption
- Network policies for pod-to-pod traffic control
- Multi-stage Dockerfiles with non-root user
- WAF rules on ALB

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Agent Framework | AgentScope |
| LLM | Llama 3.3 70B via Groq |
| Cloud | AWS |
| IaC | Terraform |
| Container Orchestration | Kubernetes (EKS) |
| CI/CD | Jenkins + ArgoCD |
| Monitoring | Prometheus + Grafana |
| Logging | ELK Stack |

---

## Author

**Jeevagan** — Senior AWS DevOps Engineer  
[GitHub](https://github.com/jeevagank)
