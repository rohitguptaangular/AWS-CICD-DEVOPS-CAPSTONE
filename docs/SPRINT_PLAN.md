# Sprint Plan

6 sprints, each ~1-2 weeks. Each sprint has: goal, tasks, learning objectives, and definition of done.

---

## Sprint 1 - Architecture, Docker, and Jenkins Setup

**Goal:** Jenkins is running on AWS EC2, can build a Docker image, and push it to ECR.

### Tasks

| # | Task | Description |
|---|---|---|
| 1.1 | Finalize architecture diagram | Draw the full system (can use draw.io or pen/paper). Include all AWS resources. |
| 1.2 | Choose/create the web app | Pick a simple app: Node.js "Hello World", Python Flask, or any existing app. Keep it simple - the app itself is not graded. |
| 1.3 | Write the Dockerfile | Create a Dockerfile that packages your app into a container image. |
| 1.4 | Create AWS ECR repository | Use AWS console (manually, for now). In Sprint 2, Terraform will do this. |
| 1.5 | Launch Jenkins EC2 instance | Launch a t3.medium EC2, install Java, install Jenkins. |
| 1.6 | Configure Jenkins | Install plugins: Docker Pipeline, AWS CLI, Kubernetes CLI, Git. |
| 1.7 | Connect GitHub to Jenkins | Add GitHub webhook so Jenkins triggers on every `git push`. |
| 1.8 | Write first Jenkinsfile | A simple pipeline with one stage: build Docker image and push to ECR. |
| 1.9 | Attach IAM role to Jenkins EC2 | Role must allow ECR push, EKS access, S3 read/write. |
| 1.10 | Test the pipeline | Push a code change → verify Jenkins triggers → Docker image appears in ECR. |

### Learning Objectives

- Understand what a Dockerfile does and how layers work
- Understand how Jenkins uses a Jenkinsfile (declarative syntax)
- Understand IAM roles - why we use roles instead of access keys on EC2
- Understand webhooks - how GitHub notifies Jenkins

### Definition of Done

- [ ] Architecture diagram is drawn and saved in `docs/`
- [ ] Dockerfile exists and `docker build` works locally
- [ ] Jenkins is accessible at `http://<EC2-IP>:8080`
- [ ] Pushing to GitHub triggers Jenkins automatically
- [ ] Docker image appears in ECR after a successful build

---

## Sprint 2 - AWS Infrastructure with Terraform + Jenkins Integration

**Goal:** All AWS infrastructure (VPC, EKS, EC2) is defined in Terraform and provisioned by Jenkins.

### Tasks

| # | Task | Description |
|---|---|---|
| 2.1 | Learn Terraform basics | Run through a basic tutorial: create an S3 bucket with Terraform. |
| 2.2 | Create S3 bucket for Terraform state | Manually (one-time). This S3 bucket stores Terraform's memory of what it created. |
| 2.3 | Write Terraform: VPC module | VPC, 2 public subnets, 2 private subnets, Internet Gateway, NAT Gateway. |
| 2.4 | Write Terraform: EC2 for Jenkins | Define the Jenkins server in Terraform (so it can be recreated). |
| 2.5 | Write Terraform: EKS cluster | EKS cluster + node group with 2 EC2 worker nodes. |
| 2.6 | Write Terraform: Security groups | Rules for Jenkins (8080, 22) and EKS nodes. |
| 2.7 | Write Terraform: ECR repository | Move ECR creation from manual to Terraform. |
| 2.8 | Configure S3 backend in Terraform | Add `backend "s3" {}` block so state is stored remotely. |
| 2.9 | Create Jenkins job: Terraform Apply | A Jenkins pipeline that runs `terraform init && terraform plan && terraform apply`. |
| 2.10 | Test Terraform via Jenkins | Trigger the Jenkins Terraform job, verify AWS resources are created. |

### Learning Objectives

- Understand the Terraform workflow: write → init → plan → apply
- Understand what `terraform state` is and why remote state matters
- Understand how modules help organize Terraform code
- Understand EKS: control plane vs worker nodes

### Definition of Done

- [ ] `terraform/` directory exists with organized `.tf` files
- [ ] `terraform plan` shows expected resources with no errors
- [ ] Running the Jenkins Terraform job creates all AWS resources
- [ ] State file is visible in S3 bucket
- [ ] EKS cluster is in "Active" state in AWS console

---

## Sprint 3 - Configuration Management with Ansible + Jenkins

**Goal:** EC2 instances are automatically configured (Docker, kubectl installed) by Ansible via Jenkins.

### Tasks

| # | Task | Description |
|---|---|---|
| 3.1 | Learn Ansible basics | Write a playbook that installs `nginx` on a test server. |
| 3.2 | Write Ansible inventory | Dynamic or static list of EC2 instances that Ansible should configure. |
| 3.3 | Playbook: Install Docker | Task: install Docker CE on EC2 nodes. |
| 3.4 | Playbook: Install kubectl | Task: install kubectl and configure kubeconfig on Jenkins server. |
| 3.5 | Playbook: Install AWS CLI | Task: install and configure `aws-cli` on nodes. |
| 3.6 | Playbook: Configure kubeconfig | Update kubeconfig on Jenkins so it can run `kubectl` against EKS. |
| 3.7 | Configure SSH key in Jenkins | Jenkins needs the EC2 private key to SSH into nodes for Ansible. |
| 3.8 | Create Jenkins job: Ansible | A pipeline stage that runs `ansible-playbook configure-nodes.yml`. |
| 3.9 | Chain jobs: Terraform → Ansible | Terraform job triggers Ansible job on success. |
| 3.10 | Test configuration | SSH into nodes, verify Docker, kubectl, and aws-cli are installed. |

### Learning Objectives

- Understand Ansible inventory and how Ansible finds servers
- Understand Ansible YAML syntax: play, tasks, modules
- Understand idempotency - running the same playbook twice gives the same result
- Understand how Jenkins passes secrets (SSH keys) securely

### Definition of Done

- [ ] `ansible/` directory exists with organized playbooks
- [ ] `ansible-playbook --syntax-check` passes with no errors
- [ ] Running the Ansible Jenkins job configures all nodes
- [ ] Docker runs on EKS nodes: `docker --version` returns output
- [ ] `kubectl get nodes` works from Jenkins server and shows EKS nodes as "Ready"

---

## Sprint 4 - Full CI/CD Pipeline to Kubernetes (EKS)

**Goal:** A single `git push` triggers the full pipeline ending in a live app on EKS.

### Tasks

| # | Task | Description |
|---|---|---|
| 4.1 | Write Kubernetes Deployment manifest | `k8s/deployment.yaml` - defines the app pods (image, replicas, resource limits). |
| 4.2 | Write Kubernetes Service manifest | `k8s/service.yaml` - type: LoadBalancer to expose app on the internet. |
| 4.3 | Write Kubernetes HPA manifest | `k8s/hpa.yaml` - HorizontalPodAutoscaler (scale 2-10 pods based on CPU). |
| 4.4 | Add health check probes | Add `livenessProbe` and `readinessProbe` to the Deployment. |
| 4.5 | Update Jenkinsfile: multi-stage | Add Deploy stage to existing Jenkinsfile (after build). |
| 4.6 | Configure kubectl in Jenkins | Jenkins pipeline must run `kubectl apply` - needs kubeconfig. |
| 4.7 | Parameterize image tag | Pipeline uses `$BUILD_NUMBER` as the image tag so each build is unique. |
| 4.8 | Add rollback step | If deployment fails, automatically rollback: `kubectl rollout undo`. |
| 4.9 | Test full pipeline | Push a code change → verify new image in ECR → new pods in EKS. |
| 4.10 | Verify zero-downtime deploy | Check that during a deployment, the app remains accessible. |

### Learning Objectives

- Understand Kubernetes Deployment rolling update strategy
- Understand what a LoadBalancer service does and how AWS creates an ALB for it
- Understand health probes - liveness vs readiness
- Understand HPA - how Kubernetes auto-scales

### Definition of Done

- [ ] `k8s/` directory has deployment, service, and hpa YAML files
- [ ] `kubectl get pods` shows app pods in "Running" state
- [ ] App is accessible via the LoadBalancer DNS name in a browser
- [ ] Making a code change and pushing to GitHub triggers the full pipeline
- [ ] New version is deployed automatically, old pods are removed

---

## Sprint 5 - Monitoring with Prometheus and Grafana

**Goal:** Dashboards show live metrics; alerts fire when something breaks.

### Tasks

| # | Task | Description |
|---|---|---|
| 5.1 | Install Helm | Helm is the Kubernetes package manager - used to install Prometheus/Grafana easily. |
| 5.2 | Install kube-prometheus-stack | Helm chart that installs Prometheus, Grafana, AlertManager in one command. |
| 5.3 | Configure Prometheus scraping | Ensure Prometheus is scraping your app's `/metrics` endpoint. |
| 5.4 | Import Grafana dashboards | Import pre-built dashboards: Kubernetes cluster overview, pod resource usage. |
| 5.5 | Create custom Grafana panel | Create a panel for a metric specific to your app (e.g., HTTP request count). |
| 5.6 | Write Prometheus alert rules | Example: alert if a pod is down for more than 2 minutes. |
| 5.7 | Configure AlertManager | Send alert emails (use Gmail SMTP or a free webhook service). |
| 5.8 | Integrate Jenkins notifications | Configure Jenkins to send email on pipeline failure. |
| 5.9 | Expose Grafana externally | Create a Service or Ingress so Grafana is accessible in a browser. |
| 5.10 | Test alerting | Manually kill a pod, verify the alert fires and notification arrives. |

### Learning Objectives

- Understand the Prometheus data model: metrics, labels, time series
- Understand the scrape model: Prometheus pulls metrics from targets
- Understand PromQL basics: `rate()`, `sum()`, `avg()`
- Understand AlertManager: routing, grouping, and inhibition

### Definition of Done

- [ ] `monitoring/` directory has Helm values files for Prometheus and Grafana
- [ ] `kubectl get pods -n monitoring` shows all pods "Running"
- [ ] Grafana is accessible in browser, shows Kubernetes dashboards
- [ ] Alert fires when a pod is deleted manually
- [ ] Jenkins sends email notification on pipeline failure

---

## Sprint 6 - Testing, Documentation, and Final Review

**Goal:** Everything is tested end-to-end, documented, and ready for evaluation.

### Tasks

| # | Task | Description |
|---|---|---|
| 6.1 | Write smoke test script | A script that hits the app URL and verifies HTTP 200 response. |
| 6.2 | Add smoke test to Jenkins | After deployment, run smoke test - fail the pipeline if it returns non-200. |
| 6.3 | Write infrastructure test | Use `terratest` or manual checks to verify EKS nodes are Ready. |
| 6.4 | Document setup guide | Step-by-step guide: how to run this pipeline from scratch. |
| 6.5 | Document troubleshooting | Common errors and their fixes for each tool. |
| 6.6 | Clean up unused resources | `terraform destroy` non-essential resources; right-size instances. |
| 6.7 | Review cost | Check AWS Cost Explorer; document estimated monthly cost. |
| 6.8 | Full end-to-end test | Delete everything, run the full pipeline from scratch, verify it works. |
| 6.9 | Prepare presentation | Create slides covering: architecture, demo, challenges, learnings. |
| 6.10 | Viva preparation | Be ready to explain every tool and every decision. |

### Learning Objectives

- Understand how to document infrastructure for handoff to others
- Understand cost analysis in AWS
- Practice explaining technical decisions clearly

### Definition of Done

- [ ] `docs/SETUP_GUIDE.md` exists and a classmate can follow it
- [ ] `docs/TROUBLESHOOTING.md` covers at least 5 real errors encountered
- [ ] Full pipeline runs from scratch without manual intervention
- [ ] AWS Cost Explorer estimate is documented
- [ ] Presentation slides cover all 5 pipeline stages

---

## Sprint Summary Timeline

```
Week 1-2   : Sprint 1 - Docker + Jenkins
Week 3-4   : Sprint 2 - Terraform
Week 5-6   : Sprint 3 - Ansible
Week 7-8   : Sprint 4 - CI/CD to EKS
Week 9-10  : Sprint 5 - Monitoring
Week 11-12 : Sprint 6 - Testing + Docs + Final
```
