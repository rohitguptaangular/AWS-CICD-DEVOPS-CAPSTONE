# System Architecture

## Overview

This document describes the full architecture of the CI/CD pipeline and the AWS infrastructure it manages.

![CI/CD Pipeline Architecture](architecture-diagram.svg)

*Code pushed to GitHub triggers Jenkins, which builds and pushes the Docker image to ECR and deploys it to EKS. Terraform provisions all infrastructure; Ansible configures the Jenkins host; Prometheus + Grafana monitor the cluster.*

---

## High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        DEVELOPER                                │
│                git push → GitHub Repository                     │
└─────────────────────────────┬───────────────────────────────────┘
                              │ Webhook (HTTP trigger)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    JENKINS (AWS EC2)                            │
│                                                                 │
│  Stage 1: BUILD                                                 │
│    └─ docker build → docker push → AWS ECR                      │
│                                                                 │
│  Stage 2: INFRASTRUCTURE (Terraform)                            │
│    └─ terraform apply → creates VPC, EKS, EC2                   │
│    └─ state stored in S3                                        │
│                                                                 │
│  Stage 3: CONFIGURATION (Ansible)                               │
│    └─ ansible-playbook → installs Docker, kubectl on nodes      │
│                                                                 │
│  Stage 4: DEPLOY (kubectl)                                      │
│    └─ kubectl apply → deploys app pods to EKS                   │
│                                                                 │
│  Stage 5: MONITOR                                               │
│    └─ Prometheus scrapes metrics                                │
│    └─ Grafana shows dashboards                                  │
│    └─ Alerts sent back to Jenkins / Email                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## AWS Infrastructure Layout

```
AWS Region (e.g., us-east-1)
│
└── VPC: 10.0.0.0/16
    │
    ├── Public Subnet: 10.0.1.0/24  (Availability Zone A)
    │   ├── Jenkins EC2 Instance        ← CI/CD server
    │   └── Application Load Balancer   ← Entry point for users
    │
    ├── Public Subnet: 10.0.2.0/24  (Availability Zone B)
    │   └── (redundancy / ALB)
    │
    ├── Private Subnet: 10.0.3.0/24 (Availability Zone A)
    │   └── EKS Worker Nodes (EC2)
    │
    ├── Private Subnet: 10.0.4.0/24 (Availability Zone B)
    │   └── EKS Worker Nodes (EC2)
    │
    ├── Internet Gateway                ← Public subnets use this
    └── NAT Gateway                     ← Private subnets use this to reach internet
```

### Why Public vs Private Subnets?

| Subnet Type | What Goes Here | Why |
|---|---|---|
| Public | Jenkins EC2, Load Balancer | Need to receive traffic from internet |
| Private | EKS worker nodes (your app pods) | Apps should NOT be directly reachable; only via Load Balancer |

---

## AWS Services Used

| Service | Purpose | Why This Service |
|---|---|---|
| EC2 | Jenkins server | Persistent server to run Jenkins |
| EKS | Kubernetes cluster | Managed Kubernetes — AWS handles control plane |
| ECR | Docker image registry | Like DockerHub but inside AWS, integrates with IAM |
| S3 | Terraform state storage | Durable, shared state so team can collaborate |
| VPC | Network isolation | Your own private network in AWS |
| IAM | Permissions & roles | Jenkins needs permission to talk to EKS, ECR, etc. |
| ALB | Load Balancer | Distributes user traffic across multiple app pods |
| CloudWatch | Log aggregation | Kubernetes and EC2 logs centrally |

---

## Kubernetes (EKS) Cluster Layout

```
EKS Cluster
│
├── kube-system namespace        ← Kubernetes internal components
│   ├── coredns                  (DNS resolution inside cluster)
│   └── aws-node                 (Networking plugin)
│
├── default namespace            ← Your web application
│   ├── Deployment               (defines how many app replicas to run)
│   ├── Service (LoadBalancer)   (exposes app to the internet)
│   └── HorizontalPodAutoscaler  (scales pods up/down based on CPU)
│
└── monitoring namespace         ← Prometheus + Grafana
    ├── Prometheus Deployment    (collects metrics)
    ├── Grafana Deployment       (visualizes metrics)
    └── AlertManager             (sends alerts)
```

### Key Kubernetes Concepts (for learning)

| Concept | Simple Explanation |
|---|---|
| Pod | Smallest unit — one running container (or a few tightly coupled ones) |
| Deployment | Says "keep 3 copies of this pod running, always" |
| Service | Gives pods a stable network address; can expose to internet |
| HPA | Watches CPU/memory and adds/removes pods automatically |
| Namespace | Like a folder — separates different apps or teams |
| Node | An EC2 instance that runs your pods |

---

## CI/CD Pipeline Stages (Jenkins)

```
git push
   │
   ▼
[Stage 1: Build]
   ├── Checkout code from GitHub
   ├── Run unit tests
   ├── docker build -t myapp:$BUILD_NUMBER .
   └── docker push to AWS ECR

   ▼
[Stage 2: Infrastructure]
   ├── terraform init
   ├── terraform plan       ← shows what will change
   └── terraform apply      ← creates/updates AWS resources

   ▼
[Stage 3: Configure]
   ├── ansible-playbook configure-nodes.yml
   ├── Install: Docker, kubectl, aws-cli on nodes
   └── Configure: kubeconfig, security settings

   ▼
[Stage 4: Deploy]
   ├── kubectl apply -f k8s/deployment.yaml
   ├── kubectl apply -f k8s/service.yaml
   ├── kubectl rollout status deployment/myapp
   └── kubectl apply -f k8s/hpa.yaml

   ▼
[Stage 5: Verify + Monitor]
   ├── Run smoke tests (is the app responding?)
   ├── Prometheus scrapes /metrics endpoint
   ├── Grafana dashboard auto-updates
   └── Alert if deployment failed → Jenkins sends email
```

---

## Security Architecture

```
IAM Roles (no hardcoded credentials):
├── Jenkins EC2 Role
│   ├── ECR: push/pull images
│   ├── EKS: describe/manage cluster
│   ├── S3: read/write terraform state
│   └── EC2: describe instances
│
└── EKS Node Role
    ├── ECR: pull images
    └── CloudWatch: send logs

Network Security Groups:
├── Jenkins SG:  Allow port 8080 (web UI) from your IP only
│                Allow port 22 (SSH) from your IP only
└── EKS SG:     Allow traffic only from Jenkins and ALB
```

---

## Cost Optimization Notes

The evaluation gives 10% weight to cost optimization. Key strategies:

| Strategy | Implementation |
|---|---|
| Right-size instances | Use t3.medium for Jenkins, t3.small for EKS nodes |
| Auto-scaling | HPA scales pods down when traffic is low |
| Spot instances | EKS node group can use spot instances for dev/test |
| Destroy when not in use | `terraform destroy` when done testing |
| S3 lifecycle policy | Move old terraform state to cheaper storage class |
| Single NAT Gateway | Use one NAT GW (not one per AZ) for lower cost |
