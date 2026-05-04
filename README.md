# End-to-End DevOps Pipeline for a Web Application with CI/CD

**Assigned by:** Herovire  
**Evaluation:** Documentation 15% | Implementation 75% | Cost Optimization 10%

---

## What This Project Builds

A fully automated pipeline where:
1. A developer pushes code to GitHub
2. Jenkins automatically picks it up
3. Jenkins builds a Docker image and pushes it to AWS ECR
4. Jenkins runs Terraform to create/update AWS infrastructure
5. Jenkins runs Ansible to configure servers
6. Jenkins deploys the app to Kubernetes (AWS EKS)
7. Prometheus and Grafana monitor everything in real time

---

## Project Documents

| Document | Purpose |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) | System design, AWS layout, data flow |
| [Tech Stack](docs/TECH_STACK.md) | Every tool used and why |
| [Sprint Plan](docs/SPRINT_PLAN.md) | 6 sprints with tasks and learning objectives |
| [Prerequisites](docs/PREREQUISITES.md) | Accounts, tools, and skills needed before starting |
| [Learning Guide](docs/LEARNING_GUIDE.md) | How to learn each tool in the right order |

---

## Project Sprints at a Glance

| Sprint | Focus | Key Output |
|---|---|---|
| Sprint 1 | Architecture + Docker + Jenkins Setup | Jenkins running on EC2, Docker image in ECR |
| Sprint 2 | Terraform + AWS Infrastructure | VPC, EKS, EC2 provisioned via Jenkins |
| Sprint 3 | Ansible Configuration Management | Servers configured via Jenkins + Ansible |
| Sprint 4 | Full CI/CD to Kubernetes (EKS) | App auto-deployed to EKS on every git push |
| Sprint 5 | Prometheus + Grafana Monitoring | Dashboards and alerts live |
| Sprint 6 | Testing + Documentation + Final Review | Production-ready, fully documented pipeline |

---

## Technology Stack Summary

```
Code           →  GitHub
CI/CD          →  Jenkins (on AWS EC2)
Containers     →  Docker + AWS ECR
Infrastructure →  Terraform
Config Mgmt    →  Ansible
Orchestration  →  Kubernetes on AWS EKS
Monitoring     →  Prometheus + Grafana
Cloud          →  AWS (VPC, EC2, EKS, ECR, S3, IAM)
```

---

## Folder Structure (will grow each sprint)

```
capstone/
├── README.md                  ← You are here
├── docs/                      ← All planning documents
│   ├── ARCHITECTURE.md
│   ├── TECH_STACK.md
│   ├── SPRINT_PLAN.md
│   ├── PREREQUISITES.md
│   └── LEARNING_GUIDE.md
├── app/                       ← Web application source code (Sprint 1)
├── terraform/                 ← Infrastructure as Code (Sprint 2)
├── ansible/                   ← Configuration playbooks (Sprint 3)
├── k8s/                       ← Kubernetes manifests (Sprint 4)
├── jenkins/                   ← Jenkinsfile and job configs (Sprint 1-4)
└── monitoring/                ← Prometheus + Grafana configs (Sprint 5)
```
