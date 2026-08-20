# Technology Stack

The tools in the pipeline, what each one does here, and why it was chosen over the
alternatives.

## Docker

Packages the Flask app and its dependencies into one image, so the same build runs
identically on a laptop, on Jenkins, and on EKS. Jenkins builds the image, ECR stores it,
EKS runs it.

Images must be built for `linux/amd64`. The EKS nodes are x86_64, so a build on an Apple
Silicon machine produces arm64 images that fail to start on the cluster - see
[TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## AWS ECR

Private container registry. Jenkins pushes to it; EKS pulls from it.

Chosen over Docker Hub for authentication: the Jenkins EC2 authenticates with its
instance-profile IAM role and the worker nodes authenticate with theirs, so no registry
credentials are stored anywhere. The permissions are deliberately asymmetric - Jenkins
can push, nodes hold `AmazonEC2ContainerRegistryReadOnly` and can only pull.

## Jenkins

The automation server. A GitHub webhook triggers the app pipeline on every push, which
builds the image, pushes it to ECR, deploys to EKS and runs a smoke test.

There are two pipelines, and they are separate on purpose:

| Pipeline | Trigger | Scope |
|---|---|---|
| `Jenkinsfile` | GitHub webhook, every push | build, push, deploy, smoke test |
| `Jenkinsfile.infra` | manual | `terraform apply` on the platform layer, Ansible, verify |

Infrastructure applies stay manual. A documentation commit should not be able to
reconcile a cluster.

## Terraform

All AWS infrastructure is defined in `.tf` files rather than clicked together in the
console, so the environment can be destroyed at the end of a session and recreated
identically. That is also the main cost control - see [COST.md](COST.md).

It is split into two root modules with separate state:

| Module | Contains | Applied by |
|---|---|---|
| `terraform/bootstrap` | VPC, subnets, NAT, Jenkins SG, Jenkins EC2 + EIP + IAM role | a human, from a laptop |
| `terraform/platform` | EKS cluster + node group, ECR, GitHub OIDC role | the Jenkins infra pipeline |

`platform` reads `bootstrap` through a `terraform_remote_state` data source, so the
dependency runs one way only and the Jenkins host is not in the state Jenkins applies.
The reasoning is in [ARCHITECTURE.md](ARCHITECTURE.md).

State lives in a versioned, encrypted S3 bucket with locking, so it survives any one
machine and cannot be corrupted by two applies at once.

## Ansible

Terraform creates servers; Ansible configures them. The playbook installs Docker, git,
kubectl and the AWS CLI on the Jenkins host and points kubeconfig at the cluster.

Chosen because it is agentless - it works over plain SSH with nothing pre-installed on
the target. It is also idempotent, so re-running it on a configured host changes nothing,
which is what makes it safe to run from a pipeline on every infra change.

Note the division of labour on the Jenkins host: **EC2 user data** installs Jenkins itself
at first boot, because it has to exist before anything else can configure it. Everything
that may need to change later lives in the Ansible playbook, because user data runs only
once and cannot be re-applied.

## Kubernetes on AWS EKS

Runs the app. A Deployment holds 2 replicas and restarts failed pods, a LoadBalancer
Service exposes them, and an HPA scales replicas on CPU. Rolling updates give
zero-downtime deploys, gated by readiness probes on `/health`.

EKS rather than self-managed Kubernetes because AWS runs and patches the control plane,
leaving only the worker nodes to manage. The trade-off is roughly $0.10/hr for the
control plane plus some EKS-specific setup: kubeconfig via `aws eks update-kubeconfig`,
and EKS access entries mapping IAM roles to Kubernetes permissions.

Objects used, all in `k8s/`: Deployment, Service, HPA, liveness and readiness probes.

## Prometheus + Grafana

Monitoring, installed as the kube-prometheus-stack Helm chart. Prometheus scrapes the
nodes, the pods and the app's `/metrics` endpoint every 15s; the alert rules in
`monitoring/` evaluate against it. Grafana provides dashboards, including a custom one
for application request rate defined in `monitoring/grafana-dashboard.yaml`.

The app exposes metrics through `prometheus-flask-exporter`, and a ServiceMonitor tells
Prometheus to scrape the app's Service.

## AWS VPC

The network everything runs in. Jenkins sits in a public subnet because GitHub webhooks
must reach it. The EKS worker nodes sit in private subnets behind a NAT gateway, so they
can pull images and reach the internet outbound but cannot be reached from it. Security
groups handle per-resource firewalling.

## How the tools relate

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
