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

**a. Remote state bucket** (name must match `terraform/bootstrap/backend.tf` and
`terraform/platform/backend.tf`):

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

Terraform is split into two root modules with **separate state files**, and the
order matters - `platform` reads `bootstrap`'s outputs:

| Module | Contains | Applied by |
|---|---|---|
| `terraform/bootstrap` | VPC, subnets, NAT, Jenkins SG, Jenkins EC2 + EIP + IAM role | a human, from a laptop |
| `terraform/platform` | EKS cluster + nodes, ECR, GitHub OIDC role | the Jenkins infra pipeline |

The split exists because Jenkins must not manage the machine it runs on. When
both layers were one module, an apply from Jenkins that changed the instance
(a `user_data` edit, say) replaced the EC2 mid-build and killed the job. The
Jenkins host is not in the `platform` state, so that can no longer happen.

**a. Bootstrap** - network + the Jenkins server. Run locally:

```bash
cd terraform/bootstrap
terraform init
terraform plan  -var="admin_ip_cidr=$(curl -s https://checkip.amazonaws.com)/32"
terraform apply -var="admin_ip_cidr=$(curl -s https://checkip.amazonaws.com)/32"
```

Outputs: `jenkins_url`, `jenkins_public_ip`, subnet ids, plus `jenkins_sg_id`
and `jenkins_role_arn` which the platform module consumes.

**b. Platform** - EKS, ECR, OIDC. Run locally the first time; after that the
Jenkins infra pipeline owns it:

```bash
cd terraform/platform
terraform init
terraform apply
```

Outputs: `ecr_repository_url`, `eks_cluster_name`, `github_actions_role_arn`.

`admin_ip_cidr` is only a bootstrap concern (it gates SSH and the Jenkins UI),
so the platform apply takes no variables - which is why the infra pipeline no
longer needs a parameter.

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
- **Infra pipeline** - Pipeline job, script path `Jenkinsfile.infra`, no
  parameters. Running this executes `terraform apply` against
  **`terraform/platform` only**, then Ansible, then a node check, all **from
  Jenkins** (Sprint 2 tasks 2.9/2.10). It reads `terraform/bootstrap`'s state to
  find the Jenkins host for the Ansible stage, but never applies it, so Jenkins
  never modifies the host it runs on.

## 6. Deploy the app + verify

Push a change (or click **Build Now** on the app pipeline). Then:

```bash
kubectl get pods                 # app pods Running
tests/infra_test.sh              # nodes Ready, pods Running, LB provisioned
tests/smoke_test.sh              # / and /health return 200 via the LoadBalancer
```

## 7. Monitoring (optional, Sprint 5)

The release name must stay `kube-prometheus-stack` - the manifests below match on it.

Both secrets have to exist **before** the Helm install, because the Prometheus and
Alertmanager pods mount them and stay pending if they are missing.

```bash
kubectl create namespace monitoring

# Alertmanager mounts this one. Placeholder here; a real setup uses an app password.
kubectl -n monitoring create secret generic alertmanager-smtp \
  --from-literal=password=placeholder

# Prometheus mounts this one to authenticate its Jenkins scrape. Generate the
# token in Jenkins under Manage Jenkins > Users > admin > Configure > API token.
kubectl -n monitoring create secret generic jenkins-token \
  --from-literal=token=<jenkins api token>

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring -f monitoring/values.yaml

# The chart alone does not scrape anything of ours or add the dashboards.
kubectl apply -f monitoring/servicemonitor.yaml     # tells Prometheus to scrape /metrics
kubectl apply -f monitoring/alert-rules.yaml        # app and Jenkins alerts
kubectl apply -f monitoring/grafana-dashboard.yaml  # app request-rate dashboard
kubectl apply -f monitoring/jenkins-dashboard.yaml  # Jenkins build health dashboard
```

### Monitoring Jenkins itself

Prometheus watches the app and the cluster, and it also watches the Jenkins host,
so a CI outage shows up the same way an app outage does. Three things make that work:

1. **The Prometheus metrics plugin on Jenkins.** Install it from Manage Plugins, then
   under Manage Jenkins > System, tick **Use authenticated endpoint**. Without that
   the endpoint is anonymous, and Jenkins' own security then refuses the request.
2. **A scrape config.** Jenkins runs on EC2, outside the cluster, so there is no
   Service for a ServiceMonitor to select. It is a static target in
   `monitoring/values.yaml` instead, pointed at the Jenkins private IP. That IP
   changes when bootstrap is rebuilt, so update it after a rebuild:
   `terraform -chdir=terraform/bootstrap output -raw jenkins_private_ip`
3. **A security group rule.** The nodes scrape from the private subnets, which the
   admin-IP rules do not cover, so `bootstrap` opens 8080 within the VPC.

The metrics path is `/prometheus/` **with the trailing slash**. Without it Jenkins
answers 302 and the target shows as down.

### Verify before trusting the dashboards

```bash
kubectl get servicemonitor,prometheusrule -n monitoring | grep herovire

# Both targets should report health "up".
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# then open http://localhost:9090/targets and look for jobs "jenkins" and "herovire-app"
```

Grafana comes up as a ClusterIP, so reach it over a port-forward (admin/admin):

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Then open http://localhost:3000 - the dashboards are "Herovire App" and "Jenkins CI".

## 8. Teardown (do this after every session - see COST.md)

**Delete any LoadBalancer services first** so their ELBs are freed (orphaned
ELBs hold VPC ENIs and block VPC deletion). Grafana is a ClusterIP, so normally
only the app has one - but check, because a Grafana service switched to
LoadBalancer during a demo will block the destroy too:

```bash
kubectl delete namespace monitoring --ignore-not-found
kubectl delete -f k8s/ --ignore-not-found
aws elb describe-load-balancers --region ap-south-1 \
  --query 'LoadBalancerDescriptions[].LoadBalancerName'   # wait until []
```

Then destroy in **reverse dependency order** - platform first, because
bootstrap owns the VPC that platform's resources sit in:

```bash
cd terraform/platform  && terraform destroy
cd ../bootstrap        && terraform destroy -var="admin_ip_cidr=$(curl -s https://checkip.amazonaws.com)/32"
```
