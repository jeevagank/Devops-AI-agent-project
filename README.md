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

A production-grade AWS DevOps project built with the assistance of AI tools. The initial infrastructure scaffold was generated using the **AgentScope** multi-agent framework, then iteratively reviewed, corrected, and hardened using **Amazon Q** and **Claude** — not from a single prompt, but through multiple rounds of AI-assisted analysis and improvement.

---

## How This Was Built

This was not a one-shot generation. The process involved:

1. **AgentScope + Llama 3.3 70B (via Groq)** — used to scaffold the initial project structure across 10 specialized agents (Terraform, Docker, Helm, Jenkins, ArgoCD, Prometheus, Grafana, ELK, Security)
2. **Amazon Q** — used to review and refine AWS-specific configurations (IAM roles, EKS, VPC, Aurora)
3. **Claude (Anthropic)** — used for iterative code review, identifying security gaps, fixing misconfigurations, and improving the overall architecture

Key improvements made through AI-assisted review:
- Removed hardcoded `ACCOUNT_ID` placeholders across 30 files
- Replaced mutable `latest` image tags with immutable git SHA tagging
- Fixed wrong IAM policy (`AmazonEKSClusterPolicy`) on cross-account deploy roles
- Replaced `docker:dind` (privileged) with Kaniko for rootless image builds
- Removed static AWS credentials that were overriding IRSA
- Fixed `agent any` in Jenkins to properly use Kubernetes pod agents
- Added Terraform bootstrap for state bucket creation
- Removed redundant `k8s/` manifests in favour of Helm as the single deployment method

---

## Project Stack

**4 applications, 15 microservices** deployed on Amazon EKS across 3 AWS accounts (dev, staging, prod) with a dedicated tools account for CI/CD.

| Layer | Technology |
|-------|-----------|
| Cloud | AWS (EKS, Aurora, MSK, Redis, ALB, WAF, Route53) |
| IaC | Terraform (module + environment separation) |
| Containers | Docker (multi-stage, non-root) + Kaniko (CI builds) |
| Deployment | Helm (per-microservice charts, env-specific values) |
| GitOps | ArgoCD (automated sync, self-heal) |
| CI/CD | Jenkins on tools EKS (IRSA, cross-account deploy) |
| Monitoring | Prometheus Operator + Grafana |
| Logging | ELK Stack (Filebeat + Logstash + Elasticsearch) |
| Database | Aurora PostgreSQL Global DB (Sydney primary, Singapore DR) |
| Messaging | MSK Kafka |
| Caching | ElastiCache Redis |

---

## Project Structure

```
output/
├── terraform/          # AWS infrastructure — modules + per-env configs + bootstrap
├── docker/             # Dockerfiles per microservice (multi-stage, non-root)
├── helm/               # Helm charts per microservice with env-specific values
├── jenkins/            # Jenkinsfiles with Kaniko builds and IRSA-based deploy
├── argocd/             # ArgoCD Application manifests
├── prometheus/         # Scrape configs and alerting rules per environment
├── grafana/            # Dashboard JSON files
├── elk/                # Filebeat, Logstash, Elasticsearch configs
└── security_report.md  # Security audit report
```

---

## Security Practices

- IRSA (IAM Roles for Service Accounts) — no static credentials in Jenkins
- Kaniko for container builds — no privileged pods
- Least-privilege cross-account IAM roles (only `eks:DescribeCluster`)
- Immutable image tags (git SHA, never `latest`)
- KMS-encrypted Terraform state with versioning and access logging
- Non-root containers with `readOnlyRootFilesystem`
- Network policies for pod-to-pod traffic control
- WAF on ALB, private EKS endpoint

---

## Author

**Jeevagan** — Senior AWS DevOps Engineer
[GitHub](https://github.com/jeevagank)
