# Learning Guide

Learn each tool in this order — each one builds on the previous.

---

## Learning Order

```
Step 1: Linux + Git           (foundation)
Step 2: Docker                (containerize the app)
Step 3: AWS Basics            (cloud fundamentals)
Step 4: Jenkins               (CI/CD automation)
Step 5: Terraform             (infrastructure as code)
Step 6: Ansible               (configuration management)
Step 7: Kubernetes            (container orchestration)
Step 8: Prometheus + Grafana  (monitoring)
```

---

## Step 1: Linux Command Line + Git

**Time needed:** 2-3 days (if you haven't used it before)

Key Linux commands you must know:
```bash
ls, cd, pwd           # navigate directories
mkdir, touch, rm      # create/delete files
cat, less, tail -f    # view file contents
chmod, chown          # file permissions
ssh user@host         # connect to remote server
scp file user@host:   # copy file to remote server
sudo                  # run as administrator
systemctl start/stop  # manage services
```

Key Git commands:
```bash
git clone <url>           # download a repo
git add <file>            # stage changes
git commit -m "message"   # save changes
git push                  # send to GitHub
git pull                  # get latest from GitHub
git status                # see what changed
git log --oneline         # see commit history
git branch                # list branches
git checkout -b feature   # create and switch to new branch
```

---

## Step 2: Docker

**Time needed:** 3-4 days

### Concepts to learn in order:

**Day 1: Images and Containers**
```bash
docker pull nginx              # download an image
docker run -p 8080:80 nginx    # run a container
docker ps                      # list running containers
docker stop <container-id>     # stop a container
docker images                  # list downloaded images
```

**Day 2: Writing a Dockerfile**
```dockerfile
FROM node:18-alpine        # start from a base image
WORKDIR /app               # set working directory
COPY package.json .        # copy files
RUN npm install            # run a command during build
COPY . .                   # copy rest of code
EXPOSE 3000                # document what port app uses
CMD ["node", "server.js"]  # command to start app
```

```bash
docker build -t myapp:v1 .    # build image from Dockerfile
docker run -p 3000:3000 myapp:v1
```

**Day 3: Docker Networks and Volumes**
```bash
docker network ls
docker volume ls
docker-compose up   # run multi-container apps (learn basics)
```

**Key concept:** An image is a blueprint. A container is a running instance of that blueprint. You can run many containers from one image.

---

## Step 3: AWS Basics

**Time needed:** 3-5 days

### Services to understand:

**EC2 (Virtual Machines)**
- Launch an EC2 instance from the console
- Choose an AMI (Amazon Machine Image) — think of it like choosing an OS
- Connect via SSH: `ssh -i ~/.ssh/key.pem ec2-user@<ip>`
- Understand: instance types, security groups, key pairs

**VPC (Networking)**
- Every EC2 instance lives inside a VPC
- VPC = your private section of the AWS cloud
- Subnets divide the VPC into smaller sections
- Internet Gateway = the door from VPC to the internet

**IAM (Identity and Access Management)**
- Users: real humans
- Roles: identities that AWS services assume (e.g., EC2 can assume a role to access S3)
- Policies: JSON documents that say what actions are allowed
- Rule: never hardcode AWS keys. Always use IAM roles.

**S3 (Object Storage)**
```bash
aws s3 ls                          # list buckets
aws s3 cp file.txt s3://my-bucket/ # upload
aws s3 sync ./folder s3://bucket/  # sync a folder
```

---

## Step 4: Jenkins

**Time needed:** 4-5 days

### Concepts to learn:

**Day 1: Install and First Job**
- Install Jenkins on an EC2 instance
- Access the UI at `http://IP:8080`
- Create a "Freestyle" job that runs `echo "Hello Jenkins"`

**Day 2: Pipelines and Jenkinsfile**
A Jenkinsfile lives in your Git repo and defines the pipeline:
```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                echo 'Building...'
                sh 'docker build -t myapp .'
            }
        }
        stage('Test') {
            steps {
                echo 'Testing...'
                sh 'npm test'
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying...'
            }
        }
    }
    post {
        failure {
            mail to: 'you@email.com', subject: 'Build Failed'
        }
    }
}
```

**Day 3: Credentials and Secrets**
- Never hardcode passwords in Jenkinsfile
- Use `Jenkins → Manage Jenkins → Credentials`
- Access in pipeline: `withCredentials([string(credentialsId: 'my-secret', variable: 'TOKEN')])`

**Day 4: Webhooks**
- In GitHub: Settings → Webhooks → Add webhook
- Payload URL: `http://your-jenkins:8080/github-webhook/`
- Jenkins will now trigger on every push

---

## Step 5: Terraform

**Time needed:** 5-7 days

### Concepts to learn:

**Day 1: First Terraform file**
```hcl
# Create an S3 bucket
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "example" {
  bucket = "my-learning-bucket-12345"
}
```
```bash
terraform init     # downloads provider plugins
terraform plan     # shows what will be created
terraform apply    # creates the resource
terraform destroy  # deletes the resource
```

**Day 2: Variables and Outputs**
```hcl
variable "region" {
  default = "us-east-1"
}

output "bucket_name" {
  value = aws_s3_bucket.example.bucket
}
```

**Day 3: Remote State**
```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "project/terraform.tfstate"
    region = "us-east-1"
  }
}
```

**Day 4-5: VPC and EKS**
- VPC resources: `aws_vpc`, `aws_subnet`, `aws_internet_gateway`, `aws_route_table`
- EKS resources: `aws_eks_cluster`, `aws_eks_node_group`

**Key concept:** Terraform tracks what it created in a "state file." If you delete the state file, Terraform forgets what it made. Remote state in S3 prevents this.

---

## Step 6: Ansible

**Time needed:** 3-4 days

### Concepts to learn:

**Day 1: Inventory and First Playbook**

Inventory file (`hosts.ini`):
```ini
[web_servers]
192.168.1.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/key.pem

[jenkins]
192.168.1.20 ansible_user=ec2-user
```

Playbook (`setup.yml`):
```yaml
---
- name: Configure web server
  hosts: web_servers
  become: yes        # run as sudo
  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present

    - name: Start nginx
      service:
        name: nginx
        state: started
```

```bash
ansible -i hosts.ini web_servers -m ping   # test connectivity
ansible-playbook -i hosts.ini setup.yml    # run playbook
```

**Day 2: Variables and Templates**
```yaml
vars:
  app_port: 3000

tasks:
  - name: Create config
    template:
      src: config.j2        # Jinja2 template
      dest: /etc/app.conf
```

**Key concept:** Ansible is idempotent — running the same playbook twice gives the same result. The `state: present` means "make sure this is installed." If it's already installed, Ansible does nothing.

---

## Step 7: Kubernetes

**Time needed:** 7-10 days — this is the most complex tool

### Learn in this order:

**Day 1-2: Core Objects**
```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:v1
        ports:
        - containerPort: 3000
```

```bash
kubectl apply -f deployment.yaml    # create/update
kubectl get pods                    # list pods
kubectl describe pod <name>         # detailed info
kubectl logs <pod-name>             # view logs
kubectl exec -it <pod> -- bash      # shell into pod
kubectl delete -f deployment.yaml   # delete
```

**Day 3-4: Services**
```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  type: LoadBalancer     # creates an AWS Load Balancer
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 3000
```

**Day 5: Health Checks**
```yaml
livenessProbe:     # restart pod if this fails
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 5

readinessProbe:    # don't send traffic if this fails
  httpGet:
    path: /ready
    port: 3000
```

**Day 6-7: HPA and Namespaces**
```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**Key concept:** A Pod is like a running process. A Deployment ensures the right number of pods are always running. A Service is the stable address to reach those pods. HPA adjusts the pod count based on load.

---

## Step 8: Prometheus + Grafana

**Time needed:** 3-4 days

### Install with Helm:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### Key PromQL Queries to learn:
```promql
# CPU usage per pod
rate(container_cpu_usage_seconds_total[5m])

# Memory usage
container_memory_usage_bytes

# HTTP request rate
rate(http_requests_total[5m])

# Pod restarts
increase(kube_pod_container_status_restarts_total[1h])
```

### Grafana: Access and explore
```bash
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
# Visit http://localhost:3000
# Default login: admin / prom-operator
```

---

## Recommended Free Resources

| Tool | Resource |
|---|---|
| Docker | [Play with Docker](https://labs.play-with-docker.com/) — free online lab |
| Kubernetes | [Killercoda](https://killercoda.com/) — free browser-based K8s playground |
| Terraform | [Terraform Getting Started](https://developer.hashicorp.com/terraform/tutorials/aws-get-started) |
| Jenkins | [Jenkins.io Tutorials](https://www.jenkins.io/doc/tutorials/) |
| Ansible | [Ansible Getting Started](https://docs.ansible.com/ansible/latest/getting_started/) |
| AWS | [AWS Skill Builder Free Tier](https://explore.skillbuilder.aws/) |
| Prometheus | [Prometheus Getting Started](https://prometheus.io/docs/prometheus/latest/getting_started/) |
