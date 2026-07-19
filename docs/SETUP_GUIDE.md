# Setup Guide - Run This Pipeline From Scratch

A step-by-step runbook to bring the whole pipeline up in a fresh AWS account and
tear it back down. Following this end to end satisfies Sprint 6's "full pipeline
from scratch" requirement.

## Prerequisites

Installed locally: `aws` CLI, `terraform`, `kubectl`, `git`, Docker. An AWS
account with admin access, and the AWS CLI configured (`aws configure`) for
region **ap-south-1**. Verify with:

```bash
aws sts get-caller-identity
```

## 1. One-time bootstrap (manual, done once per account)

Terraform needs two things to exist *before* it can run, because they can't
manage themselves:

**a. Remote state bucket** (name must match `terraform/backend.tf`):

```bash
aws s3api create-bucket --bucket herovire-capstone-tfstate-<ACCOUNT_ID> \
  --region ap-south-1 --create-bucket-configuration LocationConstraint=ap-south-1
aws s3api put-bucket-versioning --bucket herovire-capstone-tfstate-<ACCOUNT_ID> \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket herovire-capstone-tfstate-<ACCOUNT_ID> \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

**b. EC2 key pair** for SSH into Jenkins (name must match `key_name`, default
`jenkins-key`):

```bash
aws ec2 import-key-pair --key-name jenkins-key \
  --public-key-material fileb://~/.ssh/jenkins-key.pub
```

## 2. Provision infrastructure (Terraform)

> This is the **bootstrap apply** - run locally. It creates the Jenkins server
> itself, so it cannot come from Jenkins (see step 5 for the Jenkins-run apply).

```bash
cd terraform
terraform init
terraform plan -var="admin_ip_cidr=$(curl -s https://checkip.amazonaws.com)/32"
terraform apply -var="admin_ip_cidr=$(curl -s https://checkip.amazonaws.com)/32"
```

Creates: VPC (2 public + 2 private subnets, IGW, NAT), ECR repo, Jenkins EC2
(with a static EIP), EKS cluster + 2 worker nodes, and the GitHub OIDC role.
Useful outputs: `jenkins_url`, `ecr_repository_url`, `eks_cluster_name`,
`github_actions_role_arn`.

## 3. Point kubectl at the cluster

```bash
aws eks update-kubeconfig --region ap-south-1 --name herovire-eks
kubectl get nodes            # both nodes should be Ready
```

## 4. Configure Jenkins (one-time UI setup)

1. Open `terraform output jenkins_url` in a browser. Unlock with:
   `ssh -i ~/.ssh/jenkins-key.pem ec2-user@<jenkins_ip> sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
2. Install suggested plugins + **Docker Pipeline**, **Amazon ECR**, **Kubernetes CLI**.
3. Add credentials:
   - `jenkins-ssh-key` - *SSH Username with private key*, the `jenkins-key.pem`
     (used by the infra pipeline's Ansible stage).
   - A GitHub **deploy key** (read-only) so Jenkins can clone the repo.
4. Add the GitHub webhook: repo → Settings → Webhooks →
   `http://<jenkins_ip>:8080/github-webhook/`.

## 5. Create the two pipeline jobs

- **App pipeline** - Pipeline job, "Pipeline script from SCM", script path
  `Jenkinsfile`. This builds the image, pushes to ECR, deploys to EKS, and runs
  the smoke test. Triggered by the GitHub webhook on every push.
- **Infra pipeline** - Pipeline job, script path `Jenkinsfile.infra`, parameter
  `ADMIN_IP_CIDR`. Running this executes `terraform apply` + Ansible + a node
  check **from Jenkins** (Sprint 2 tasks 2.9/2.10). Because the Jenkins EC2 is
  already in state, this apply is an idempotent reconcile - it will not recreate
  the server.

## 6. Deploy the app + verify

Push a change (or click **Build Now** on the app pipeline). Then:

```bash
kubectl get pods                 # app pods Running
tests/infra_test.sh              # nodes Ready, pods Running, LB provisioned
tests/smoke_test.sh              # / and /health return 200 via the LoadBalancer
```

## 7. Monitoring (optional, Sprint 5)

```bash
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f monitoring/values.yaml
```

Grafana is exposed as a LoadBalancer (admin/admin).

## 8. Teardown (do this after every session - see COST.md)

**Delete both LoadBalancer services first** so their ELBs are freed (orphaned
ELBs block VPC deletion):

```bash
kubectl delete svc herovire-app
kubectl delete svc -n monitoring kube-prometheus-stack-grafana
cd terraform && terraform destroy
```

> In this repo the `/deploy` helper automates steps 2-3, 6, and 8; this guide is
> the manual path it is built on.
