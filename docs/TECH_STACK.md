# Technology Stack

Each tool is listed with: what it does, why we use it, and what you will learn from it.

---

## 1. Docker

**What:** Packages your application and all its dependencies into a portable "container image."

**Why in this project:**
- Makes the app run identically on your laptop, Jenkins, and AWS EKS
- One Dockerfile → reproducible builds every time
- Jenkins builds the image; EKS runs it

**What you will learn:**
- Writing a Dockerfile (FROM, RUN, COPY, CMD)
- Building and tagging images
- Pushing images to a registry (ECR)
- The difference between an image and a container

---

## 2. AWS ECR (Elastic Container Registry)

**What:** A Docker image registry hosted inside AWS (like DockerHub, but private and integrated with AWS IAM).

**Why in this project:**
- Jenkins pushes built images here
- EKS pulls images from here when deploying pods
- No credentials needed — uses IAM roles instead

**What you will learn:**
- Creating an ECR repository
- Authenticating Docker to ECR
- Image tagging conventions (e.g., `myapp:latest`, `myapp:v1.0.3`)

---

## 3. Jenkins

**What:** An open-source automation server that runs your CI/CD pipeline.

**Why in this project:**
- Watches GitHub for new commits (webhook)
- Orchestrates every stage: build → provision → configure → deploy → monitor
- Central hub that ties every other tool together

**What you will learn:**
- Installing Jenkins on EC2
- Creating a Declarative Pipeline (Jenkinsfile)
- Using credentials/secrets securely in pipelines
- Jenkins plugins (Docker, Kubernetes, AWS CLI)
- Understanding stages, steps, and agents in a Jenkinsfile

---

## 4. Terraform

**What:** Infrastructure as Code (IaC) tool that lets you define AWS resources in `.tf` files and provision them with a single command.

**Why in this project:**
- Replaces clicking around the AWS console
- Infrastructure is version-controlled in Git
- Can recreate the exact same environment (dev, staging, prod) reliably
- State file in S3 means multiple team members can collaborate

**What you will learn:**
- Terraform basics: providers, resources, variables, outputs
- Writing VPC, subnet, security group, EC2, and EKS resources
- `terraform init`, `terraform plan`, `terraform apply`, `terraform destroy`
- Remote state with S3 and state locking with DynamoDB

---

## 5. Ansible

**What:** Configuration management tool. Connects to servers over SSH and runs tasks (install packages, set configs, start services).

**Why in this project:**
- After Terraform creates EC2 instances (empty servers), Ansible configures them
- Installs Docker, kubectl, aws-cli on Jenkins and EKS nodes
- Ansible is agentless — no software needs to be installed on target servers first

**What you will learn:**
- Ansible inventory files (list of servers to configure)
- Writing playbooks (YAML-based task lists)
- Ansible modules: `apt`, `yum`, `copy`, `template`, `service`
- Running Ansible from Jenkins

---

## 6. Kubernetes (K8s)

**What:** Container orchestration system. Runs and manages your Docker containers at scale.

**Why in this project:**
- Automatically restarts crashed pods
- Scales up pods when traffic is high, scales down when low
- Rolling updates (deploy new version with zero downtime)
- Load balances traffic across multiple pod replicas

**What you will learn:**
- Core objects: Pod, Deployment, Service, ConfigMap, HPA
- Writing YAML manifests
- `kubectl` commands: apply, get, describe, logs, exec
- Namespaces and how to organize cluster resources
- Kubernetes health checks: liveness and readiness probes

---

## 7. AWS EKS (Elastic Kubernetes Service)

**What:** AWS-managed Kubernetes. AWS runs and maintains the Kubernetes control plane for you.

**Why in this project:**
- You only manage worker nodes (EC2 instances); AWS manages the master nodes
- Deep integration with AWS services (IAM, ECR, ALB, CloudWatch)
- Production-grade Kubernetes without the operational overhead

**What you will learn:**
- How EKS differs from self-managed Kubernetes
- Creating an EKS cluster with Terraform
- Configuring `kubeconfig` to connect `kubectl` to EKS
- IAM roles for service accounts (IRSA)

---

## 8. Prometheus

**What:** Monitoring system that collects and stores metrics (numbers over time) from your application and infrastructure.

**Why in this project:**
- Scrapes metrics from Kubernetes nodes, pods, and your app every 15 seconds
- Stores them in a time-series database
- Powers the alerting rules

**What you will learn:**
- How Prometheus scrapes targets (`/metrics` endpoint)
- PromQL (Prometheus Query Language) basics
- Setting up alert rules (e.g., "alert if pod restarts > 5 times in 10 minutes")
- Installing Prometheus in Kubernetes using Helm

---

## 9. Grafana

**What:** Visualization tool that connects to Prometheus and displays metrics as beautiful dashboards.

**Why in this project:**
- Makes Prometheus data human-readable and visual
- Pre-built dashboards for Kubernetes (CPU, memory, pod status, etc.)
- Alerting channel that can send messages to email/Slack

**What you will learn:**
- Connecting Grafana to Prometheus as a data source
- Importing pre-built dashboards
- Creating custom panels
- Setting up alert notifications

---

## 10. AWS VPC (Virtual Private Cloud)

**What:** Your own isolated private network inside AWS.

**Why in this project:**
- Controls exactly which resources can talk to which
- Jenkins is in a public subnet (reachable from internet for webhooks)
- EKS nodes are in private subnets (not directly reachable — more secure)

**What you will learn:**
- VPC CIDR blocks and subnetting
- Public vs private subnets
- Internet Gateway vs NAT Gateway
- Security Groups (stateful firewall rules)

---

## Tools Relationship Map

```
GitHub ──webhook──► Jenkins
                       │
          ┌────────────┼────────────────────┐
          │            │                    │
        Docker      Terraform            Ansible
          │            │                    │
        ECR         AWS VPC             EC2 Config
          │         AWS EKS                 │
          │            │                    │
          └────────────┴────────────────────┘
                       │
                   kubectl
                       │
                   AWS EKS
                    (Pods)
                       │
              Prometheus ◄── scrapes metrics
                       │
                   Grafana
                 (Dashboards)
```
