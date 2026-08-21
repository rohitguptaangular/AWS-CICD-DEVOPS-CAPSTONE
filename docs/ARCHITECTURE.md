# System Architecture

## Overview

This document describes the CI/CD pipeline and the AWS infrastructure it manages,
as actually built. Everything here is provisioned by the Terraform in `terraform/`,
which is split into two root modules with separate state - `bootstrap/` (network and
the Jenkins server, applied by hand) and `platform/` (EKS, ECR, OIDC, applied by the
Jenkins infra pipeline). See "Why the Terraform is split in two" below.

![CI/CD Pipeline Architecture](architecture-diagram.svg)

*Code pushed to GitHub triggers Jenkins, which builds and pushes the Docker image to
ECR and deploys it to EKS. Terraform provisions all infrastructure; Ansible configures
the Jenkins host; Prometheus and Grafana monitor the cluster.*

Region is `ap-south-1`. The two availability zones are picked at plan time from
`aws_availability_zones`, so the stack is not pinned to specific AZ names.

---

## What happens on a push

```
Developer
   |  git push
   v
GitHub  --webhook (port 8080)-->  Jenkins on EC2
                                     |
                                     |  Jenkinsfile
                                     v
                    Checkout -> Build image -> ECR login
                             -> Tag & Push -> Deploy to EKS
                             -> Smoke Test
                                     |
                                     v
                    ECR  --image pull-->  EKS worker nodes
                                     |
                            Service (LoadBalancer)
                                     |
                                     v
                                   Users
```

Provisioning and configuration are a **separate pipeline** (`Jenkinsfile.infra`), not
stages of the app build:

```
Jenkinsfile.infra:  Checkout -> Terraform Apply -> Ansible Configure -> Verify
```

They are split because they run on different cadences. The app pipeline runs on every
push; the infra pipeline runs only when infrastructure changes.

---

## AWS Infrastructure Layout

```
Region: ap-south-1
│
└── VPC: 10.0.0.0/16
    │
    ├── Public Subnet:  10.0.1.0/24   (AZ a)
    │   ├── Jenkins EC2 (t3.medium, Amazon Linux 2023, static EIP)
    │   └── Load Balancer for the app Service
    │
    ├── Public Subnet:  10.0.2.0/24   (AZ b)
    │
    ├── Private Subnet: 10.0.11.0/24  (AZ a)
    │   └── EKS worker nodes
    │
    ├── Private Subnet: 10.0.12.0/24  (AZ b)
    │   └── EKS worker nodes
    │
    ├── Internet Gateway   ← route for the public subnets
    └── NAT Gateway (one)  ← private subnets reach the internet through this
```

### Why the Terraform is split in two

| Module | State key | Contains | Applied by |
|---|---|---|---|
| `terraform/bootstrap` | `bootstrap/terraform.tfstate` | VPC, subnets, IGW, NAT, Jenkins SG, Jenkins EC2 + EIP + IAM role | a human, from a laptop |
| `terraform/platform` | `platform/terraform.tfstate` | EKS cluster + node group, ECR, GitHub OIDC role, EKS API ingress rule | the Jenkins infra pipeline |

The two modules change at different rates and are applied by different people.
`bootstrap` is the foundation, the network and the Jenkins host itself. It changes rarely
and a human applies it from a laptop. `platform` holds the parts the delivery pipeline
owns, so Jenkins applies that one itself.

Splitting them keeps the dependency one-way. `platform` reads `bootstrap` through a
`terraform_remote_state` data source, since it needs the subnet ids, the Jenkins security
group id and the Jenkins role ARN. The Jenkins host is not in the `platform` state, so an
apply run from Jenkins cannot modify or replace the machine the build is running on. The
general rule is that **a CI server should not manage the infrastructure it runs on.** The
alternative is an ephemeral runner, which is what the GitHub Actions path already does,
since a runner created and destroyed per job has no permanent host to protect.

### Why public vs private subnets

| Subnet | What runs there | Reason |
|---|---|---|
| Public | Jenkins EC2, load balancer | Must accept traffic from the internet |
| Private | EKS worker nodes | Pods should not be directly reachable; traffic arrives via the load balancer |

There is a **single NAT gateway** rather than one per AZ. One NAT is a single point of
failure for outbound traffic from private subnets, which a production setup would not
accept, but it roughly halves the NAT cost and is the right trade for this project.

---

## AWS Services Used

| Service | Purpose | Why this service |
|---|---|---|
| EC2 | Jenkins server | Persistent host for the CI/CD orchestrator |
| EKS | Kubernetes cluster | Managed control plane, so AWS runs and patches it |
| ECR | Image registry | Private registry inside AWS, authenticated by IAM instead of stored credentials |
| S3 | Terraform state | Durable, versioned, shareable remote state |
| VPC | Network isolation | Own network, with public and private tiers |
| IAM | Roles and permissions | Instance roles instead of hardcoded keys |
| ELB | Load balancer | Created automatically by the Kubernetes Service |

The app `Service` is `type: LoadBalancer` with no extra annotations, so EKS provisions a
**Classic Load Balancer**. An ALB would need the AWS Load Balancer Controller and an
Ingress, which this project does not install.

---

## EKS Cluster Layout

```
EKS Cluster: herovire-eks
│
├── kube-system
│   ├── coredns          (in-cluster DNS)
│   ├── aws-node         (VPC CNI networking)
│   └── metrics-server   (installed separately; the HPA needs it)
│
├── default              ← the application
│   ├── Deployment              herovire-app, 2 replicas
│   ├── Service                 type LoadBalancer, public entry point
│   └── HorizontalPodAutoscaler 2 to 10 replicas at 50% CPU
│
└── monitoring           ← kube-prometheus-stack, installed with Helm
    ├── Prometheus       (scrapes the app and the nodes)
    ├── Grafana          (dashboards, exposed as a LoadBalancer)
    └── Alertmanager     (alert routing)
```

Node group: 2 x t3.medium in the private subnets, desired 2, min 1, max 3, on-demand
capacity. The HPA scales pods between 2 and 10; the node group bounds how many nodes
those pods spread across. There is no Cluster Autoscaler installed, so if pod demand
ever exceeded what 3 nodes can hold, the extra pods would stay `Pending` rather than
triggering new nodes. For an app this small that ceiling is never reached, but it is
the next thing to add before this could take real traffic.

Pods expose `/metrics` via `prometheus-flask-exporter`, and a `ServiceMonitor` tells
Prometheus to scrape them. The Service needs an `app` label of its own for that to
work, not just a selector.

---

## Security

**IAM roles, no static credentials anywhere in the pipeline.**

| Role | Permissions | Note |
|---|---|---|
| Jenkins EC2 role | `AdministratorAccess` | Broad on purpose, see below |
| EKS cluster role | `AmazonEKSClusterPolicy` | Standard control plane role |
| EKS node role | `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly` | Nodes only pull images, never push |
| GitHub Actions role | `AmazonEC2ContainerRegistryPowerUser` | Assumed via OIDC, no stored AWS keys |

The Jenkins role holds `AdministratorAccess` because the infra pipeline runs
`terraform apply` from Jenkins, and that apply creates VPC, IAM, EKS and EC2 resources.
Scoping it precisely would mean enumerating every permission Terraform needs across all
of those services. In production this would be a scoped provisioning role, or Jenkins
would assume a role via OIDC the way the GitHub Actions path already does. It is called
out in `terraform/bootstrap/ec2-jenkins.tf` rather than left implicit.

**Security groups**

```
Jenkins SG
├── 22   from admin IP only          (SSH)
├── 8080 from admin IP only          (Jenkins UI)
├── 8080 from GitHub webhook ranges  (push notifications)
└── all outbound                     (required, or dnf and Docker pulls fail)
```

The admin IP is passed in as `admin_ip_cidr` at apply time rather than hardcoded,
because a home connection does not keep a fixed address.

EKS worker nodes sit in private subnets with no public IPs, so they are reachable only
through the load balancer and from inside the VPC.

---

## GitOps path (additional)

Alongside the Jenkins pipeline there is a second delivery route, described fully in
[MODERN_ALTERNATIVE.md](MODERN_ALTERNATIVE.md):

```
git push -> GitHub Actions -> OIDC to AWS -> build + push to ECR
         -> commit new image tag into k8s/deployment.yaml
                                  |
                     ArgoCD (in cluster) watches the repo
                                  |
                          reconciles EKS to match git
```

The difference is direction. Jenkins **pushes** changes into the cluster; ArgoCD
**pulls** the desired state from git and corrects drift. The Terraform for the OIDC
provider and role is in `terraform/platform/github-oidc.tf`.

---

## Design choices that control cost

| Choice | Effect |
|---|---|
| Single NAT gateway instead of one per AZ | Removes a fixed hourly charge per extra AZ |
| t3.medium nodes, desired 2 | Smallest size that comfortably runs the app plus the monitoring stack |
| Node group min 1, max 3 | Cluster cannot silently scale into a large bill |
| 3 day Prometheus retention | Keeps monitoring storage small |
| ECR lifecycle policy on untagged images | Old layers expire instead of accumulating |
| `terraform destroy` after every session | The stack only costs money while actively in use |

Figures and per-session numbers are in [COST.md](COST.md).
