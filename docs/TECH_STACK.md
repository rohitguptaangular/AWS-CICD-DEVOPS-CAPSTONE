# Technology Stack

The tools in the pipeline, why each one is here, and what I actually got out of using it.

## Docker

Packages the Flask app and its dependencies into one image so the exact same build runs on my laptop, on Jenkins, and on EKS. Jenkins builds the image, ECR stores it, EKS runs it.

Main things I picked up: writing a Dockerfile (FROM, RUN, COPY, CMD), tagging images, and the difference between an image and a container. Also learned the hard way that images built on an Apple Silicon Mac need `--platform linux/amd64` or the pods won't start (details in [TROUBLESHOOTING.md](TROUBLESHOOTING.md)).

## AWS ECR

Private Docker registry inside AWS. Jenkins pushes here, EKS pulls from here when it deploys pods. The reason it beats DockerHub for this project is auth: the Jenkins EC2 authenticates through its instance-profile IAM role, so no registry credentials are stored anywhere.

## Jenkins

The automation server at the center of the pipeline. A GitHub webhook triggers it on every push, and it runs the whole chain: build the image, push to ECR, deploy to EKS, smoke test. A second pipeline (`Jenkinsfile.infra`) handles terraform apply and the Ansible playbook.

Learning it meant getting comfortable with declarative Jenkinsfiles (stages, steps, agents), the credentials store, and a handful of plugins (Docker Pipeline, AWS CLI, Kubernetes CLI, Git). Installing and un-breaking Jenkins itself on EC2 taught me as much as the pipelines did - see the Java 21 crash-loop entry in the troubleshooting doc.

## Terraform

All AWS infrastructure in this repo (VPC, subnets, security groups, the Jenkins EC2, ECR, the EKS cluster and node group) is defined in `.tf` files instead of being clicked together in the console. That means the whole environment can be destroyed at the end of a work session and recreated identically the next day, which is also how I kept the AWS bill down.

Core skills from this sprint: providers, resources, variables and outputs, the init/plan/apply/destroy loop, and remote state in S3 with locking so state survives my laptop.

## Ansible

Terraform hands over empty servers; Ansible turns them into useful ones. The playbook installs Docker, kubectl, and the AWS CLI on the Jenkins host over plain SSH. No agent needs to be installed on the target first, which is why I picked it over alternatives.

Along the way I learned inventories, playbook YAML, the common modules (`yum`, `copy`, `service`), handlers, and why idempotency matters: re-running the playbook on an already-configured box changes nothing.

## Kubernetes on AWS EKS

Runs the app. A Deployment keeps 2+ replicas alive and restarts crashed pods, a LoadBalancer Service exposes them, and an HPA scales the replica count on CPU. Rolling updates give zero-downtime deploys, which I verified live during the Sprint 4 demo.

I went with EKS rather than self-managed Kubernetes because AWS runs the control plane; I only manage worker nodes. The trade-off is cost (~$0.10/hr for the control plane) and some EKS-specific glue: aws-auth, kubeconfig via `aws eks update-kubeconfig`, and IAM integration.

The objects I now know well from writing the manifests in `k8s/`: Deployment, Service, HPA, plus liveness/readiness probes and the everyday kubectl verbs (apply, get, describe, logs, exec).

## Prometheus + Grafana

Monitoring, installed as the kube-prometheus-stack Helm chart. Prometheus scrapes the nodes, the pods, and the app's `/metrics` endpoint every 15s and stores time series; the alert rules in `monitoring/` fire off it. Grafana sits on top for dashboards - the pre-built Kubernetes ones covered most of what I needed, plus one custom panel for app request rate.

This sprint was my introduction to PromQL (`rate()`, `increase()`) and to ServiceMonitors, which took some debugging to get scraping correctly after the AWS account migration.

## AWS VPC

The network everything lives in. Jenkins sits in a public subnet because GitHub webhooks have to reach it; the EKS worker nodes sit in private subnets behind a NAT gateway, so they can pull images but can't be reached from the internet. Security groups do the per-resource firewalling.

Writing this in Terraform is where CIDR blocks, public vs private subnets, and Internet Gateway vs NAT Gateway finally clicked for me.

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
