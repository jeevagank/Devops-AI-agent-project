# Production AWS DevOps Platform — 15 Microservices, 4 AWS Accounts

A production-grade AWS DevOps platform covering infrastructure provisioning, CI/CD, GitOps continuous delivery, progressive delivery, observability, and security — built for 15 microservices deployed across dev, staging, and prod EKS clusters, with a dedicated tools account running Jenkins.

---

## Architecture at a Glance

```
┌─────────────────────────────────────────────────────────────────┐
│  Tools Account                                                  │
│  ┌─────────────────────┐   ┌──────────────────────────────┐    │
│  │  Jenkins Controller  │   │  Tools EKS                   │    │
│  │  (EC2 m5.xlarge)    │──▶│  Jenkins Agent Pods          │    │
│  │  Ansible + JCasC    │   │  (Kaniko · Trivy · SonarQube)│    │
│  └─────────────────────┘   └──────────────────────────────┘    │
│           │ IRSA  │ cross-account sts:AssumeRole               │
└───────────┼───────┼─────────────────────────────────────────────┘
            │       │ git push (image tag)
            ▼       ▼
┌──────────────────────────────────────────────────────────────────┐
│  Git Repository                                                  │
│  ArgoCD detects change → syncs to correct EKS cluster           │
└──────────────────────────────────────────────────────────────────┘
            │
    ┌───────┼───────┐
    ▼       ▼       ▼
  Dev     Staging  Prod
  EKS     EKS      EKS
```

---

## Key Engineering Decisions

### Jenkins Controller on EC2 — Not in Kubernetes

Jenkins controller runs on a dedicated EC2 instance (`m5.xlarge`, 100 GB EBS) in the tools account, provisioned and configured entirely by Ansible (no manual setup). Agent pods spin up on the tools EKS cluster on demand using the Kubernetes plugin.

**Why:** EKS upgrades, node disruptions, and pod evictions do not affect the Jenkins controller. EBS-backed `JENKINS_HOME` survives restarts. Ansible + JCasC means the entire Jenkins config is version-controlled and reproducible from scratch in minutes.

### GitOps with ArgoCD — Jenkins Never Touches Prod Directly

Jenkins builds, tests, and pushes images to ECR. It then commits the new image tag back to Git (`values-prod.yaml`). ArgoCD watches the repository and syncs the change to the correct EKS cluster automatically.

- `selfHeal: true` — ArgoCD corrects any manual drift
- `prune: true` — removed resources are cleaned up automatically
- 45 ArgoCD Application manifests — one per microservice per environment (dev / staging / prod)
- Each Application targets the correct EKS API server and namespace

**Why:** No pipeline has direct `kubectl` access to production. The Git repository is the single source of truth. Rollback is a `git revert`.

### Argo Rollouts — Canary and Blue-Green Per Microservice

Every microservice uses `kind: Rollout` (Argo Rollouts) instead of `kind: Deployment`. The strategy is switchable per environment via `values.yaml`:

**Canary** (default for dev/staging):
```
10% → wait 5 min → 30% → wait 5 min → 60% → wait 5 min → 100%
```
At each step, an `AnalysisTemplate` queries Prometheus. If HTTP success rate drops below 95%, the rollout is automatically aborted and traffic is returned to stable.

**Blue-Green** (prod):
- Green pods are deployed and exposed via a preview service
- `autoPromotionEnabled: false` — a human approves the cutover
- Old (blue) pods are kept for 30 seconds after cutover for instant rollback
- Traffic switches by updating the active service selector (`version: blue` → `version: green`)

### AnalysisTemplate — Prometheus-Based Auto-Rollback

```yaml
successCondition: result[0] >= 0.95   # 95% HTTP success rate required
failureLimit: 3                        # 3 consecutive failures trigger rollback
query: sum(rate(http_requests_total{status!~"5.."}[5m]))
       / sum(rate(http_requests_total[5m]))
```

No manual intervention needed for a bad canary — Argo Rollouts detects it and rolls back automatically.

### Kaniko — Rootless Container Builds

Docker-in-Docker (`docker:dind`) requires `privileged: true` — a significant security risk on shared EKS nodes. All 15 microservice pipelines use Kaniko instead, which builds OCI-compliant images entirely in user-space inside a standard pod. No privileged containers. No Docker daemon.

### IRSA — No Static AWS Credentials Anywhere

Jenkins agent pods assume an IAM role via Kubernetes service account annotation (IRSA). The role allows:
- ECR push/pull in the tools account
- `sts:AssumeRole` into deploy roles in dev, staging, prod

The deploy roles in each target account permit only `eks:DescribeCluster` — enough to generate a kubeconfig. Actual deployment permissions are enforced by Kubernetes RBAC in each cluster. There are zero static AWS access keys in this codebase.

---

## Stack

| Layer | Technology |
|---|---|
| Cloud | AWS — EKS, Aurora PostgreSQL, MSK Kafka, ElastiCache Redis, ALB, WAF, Route53 |
| Infrastructure as Code | Terraform — module + environment separation, KMS-encrypted remote state |
| Containers | Docker multi-stage builds (non-root), Kaniko for CI |
| Deployment | Helm — per-microservice charts, env-specific value overrides |
| GitOps | ArgoCD — 45 Application manifests, selfHeal, prune |
| Progressive Delivery | Argo Rollouts — canary + blue-green, AnalysisTemplate auto-rollback |
| CI/CD | Jenkins — EC2 controller (Ansible/JCasC), EKS agent pods |
| Monitoring | Prometheus Operator, ServiceMonitor CRDs, Node Exporter, Grafana |
| Logging | ELK Stack — Filebeat, Logstash, Elasticsearch |
| Security | IRSA, Kaniko, NetworkPolicy, WAF, KMS, non-root containers, read-only root filesystem |

---

## Infrastructure — 4 AWS Accounts

| Account | Purpose | Key Resources |
|---|---|---|
| tools | CI/CD platform | Jenkins EC2, tools EKS, ECR |
| dev | Development | EKS, Aurora, MSK, Redis |
| staging | Pre-prod testing | EKS, Aurora, MSK, Redis, Filebeat |
| prod | Live traffic | EKS, Aurora Global DB (Sydney + Singapore DR), MSK, Redis |

Each account has its own Terraform state in an S3 bucket with KMS encryption, versioning, access logging, and DynamoDB locking. A separate Terraform bootstrap creates these state resources before any environment is provisioned.

---

## CI/CD Flow — End to End

```
Developer pushes code
        │
        ▼
Jenkins detects change (GitHub webhook)
        │
        ├── Stage: Build — Kaniko builds image, tags with git SHA, pushes to ECR
        ├── Stage: Test  — Unit tests, Trivy image scan, SonarQube analysis
        ├── Stage: Update Git — sed replaces image tag in values-<env>.yaml, git push
        │
        ▼
ArgoCD detects Git change (3-minute poll or webhook)
        │
        ▼
Argo Rollouts begins progressive delivery
        │
        ├── Canary: 10% → AnalysisTemplate checks Prometheus → 30% → 60% → 100%
        └── Blue-Green: deploy green, preview service live, human approves cutover
```

---

## Security Highlights

- No `latest` tags — all images are tagged with the git commit SHA
- No privileged pods — Kaniko replaces docker:dind
- No static credentials — IRSA throughout, cross-account via STS
- Least-privilege IAM — deploy roles allow only `eks:DescribeCluster`
- NetworkPolicy — pods accept traffic only from ALB controller, same-namespace services, and Prometheus
- Private EKS endpoint — cluster API not reachable from the internet
- WAF on ALB — managed rule groups for OWASP Top 10
- KMS encryption — EKS secrets, Aurora, MSK, S3 state buckets, EBS volumes
- Non-root containers — `runAsUser: 1000`, `readOnlyRootFilesystem: true`, all capabilities dropped

---

## Project Structure

```
output/
├── terraform/
│   ├── bootstrap/          # S3, KMS, DynamoDB — must run first
│   ├── modules/            # Reusable modules (VPC, EKS, RDS, autoscaler…)
│   └── envs/               # Per-account configs (tools, dev, staging, prod, dr)
├── helm/
│   └── microservice*/      # 15 charts — templates, values.yaml, values-dev/staging/prod.yaml
├── argocd/
│   └── microservice*-{dev,staging,prod}.yaml   # 45 Application manifests
├── jenkins/
│   └── microservice*/Jenkinsfile               # 15 pipelines (Kaniko + GitOps commit)
├── ansible/
│   ├── inventory/          # SSM-based inventory (no SSH)
│   ├── group_vars/         # Jenkins version, plugins, cluster config
│   ├── playbooks/          # Entry point: jenkins.yml
│   └── roles/jenkins/      # tasks, templates (JCasC Jinja2), handlers, defaults
├── prometheus/             # Scrape configs and alerting rules
├── grafana/                # Dashboard JSONs
├── elk/                    # Filebeat, Logstash, Elasticsearch configs
└── docker/                 # Dockerfiles per microservice (multi-stage, non-root)
```

---

## Author

**Jeevagan** — Senior AWS DevOps Engineer
[GitHub](https://github.com/jeevagank)
