# Prerequisites

Everything you need to set up BEFORE starting Sprint 1.

---

## Accounts Required

| Account | Free Tier? | Notes |
|---|---|---|
| **AWS** | Yes (12 months) | Most services used here are in free tier. EKS is NOT free (~$0.10/hr for control plane). |
| **GitHub** | Yes | Create a repository for your project source code. |
| **DockerHub** | Yes | Optional — we use ECR, but DockerHub is useful for learning locally. |

### AWS Free Tier Warning

EKS control plane costs ~$72/month. To minimize cost:
- Spin up EKS only when you need it
- Use `terraform destroy` when done for the day
- Use the smallest EC2 instances (t3.micro or t3.small) for worker nodes

---

## Software to Install on Your Local Machine

### 1. AWS CLI v2

Used to interact with AWS from your terminal.

```bash
# MacOS
brew install awscli

# Verify
aws --version
```

After installing, configure it:
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (e.g., us-east-1), Output format (json)
```

> How to get Access Key: AWS Console → IAM → Users → Your User → Security credentials → Create access key

---

### 2. Terraform

Used to write and apply infrastructure code.

```bash
# MacOS
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify
terraform --version
```

---

### 3. kubectl

Kubernetes command-line tool.

```bash
# MacOS
brew install kubectl

# Verify
kubectl version --client
```

---

### 4. Docker Desktop

For building and testing Docker images locally.

- Download from: https://www.docker.com/products/docker-desktop

```bash
# Verify
docker --version
```

---

### 5. Git

Version control (usually pre-installed on Mac/Linux).

```bash
# MacOS (if not installed)
brew install git

# Verify
git --version

# Configure
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

---

### 6. Ansible (optional for local testing)

```bash
# MacOS
brew install ansible

# Verify
ansible --version
```

---

### 7. Helm

Kubernetes package manager (needed for Sprint 5).

```bash
# MacOS
brew install helm

# Verify
helm version
```

---

## AWS Account Setup (One-Time)

### Step 1: Create IAM User for Development

Do NOT use the root account for daily work.

1. AWS Console → IAM → Users → Add user
2. Username: `devops-student`
3. Permissions: Attach `AdministratorAccess` (for learning; restrict later in production)
4. Download the CSV with Access Key and Secret Key

### Step 2: Create Key Pair for EC2 SSH

1. AWS Console → EC2 → Key Pairs → Create key pair
2. Name: `devops-key`
3. Format: `.pem`
4. Download and save to `~/.ssh/devops-key.pem`
5. Fix permissions: `chmod 400 ~/.ssh/devops-key.pem`

### Step 3: Create S3 Bucket for Terraform State

1. AWS Console → S3 → Create bucket
2. Name: `your-name-terraform-state` (must be globally unique)
3. Region: `us-east-1` (or your chosen region)
4. Block all public access: YES
5. Enable versioning: YES (so you can recover old state)

### Step 4: Configure AWS CLI

```bash
aws configure
AWS Access Key ID: <from CSV>
AWS Secret Access Key: <from CSV>
Default region name: us-east-1
Default output format: json
```

Verify it works:
```bash
aws sts get-caller-identity
# Should show your account ID and user ARN
```

---

## GitHub Repository Setup

### Step 1: Create Repository

1. Go to github.com → New repository
2. Name: `devops-capstone`
3. Visibility: Private
4. Initialize with README: Yes

### Step 2: Clone Locally

```bash
git clone https://github.com/YOUR_USERNAME/devops-capstone.git
cd devops-capstone
```

### Step 3: Set Up Folder Structure

```bash
mkdir -p app terraform ansible k8s jenkins monitoring docs
touch README.md
git add .
git commit -m "Initial project structure"
git push
```

---

## Knowledge Prerequisites

You do not need to be an expert, but basic familiarity with these will help:

| Topic | Minimum Level | Where to Learn |
|---|---|---|
| Linux command line | Can navigate directories, run commands | [Linux Journey](https://linuxjourney.com/) |
| Git basics | `git add`, `commit`, `push`, `pull` | [Git Official Docs](https://git-scm.com/doc) |
| Basic networking | IP addresses, ports, HTTP | Any "Networking for beginners" video |
| YAML syntax | Can read and write YAML files | [Learn YAML in Y Minutes](https://learnxinyminutes.com/docs/yaml/) |
| Basic Python or any scripting | Can write a simple script | Not strictly required |

---

## Checklist Before Starting Sprint 1

- [ ] AWS account created
- [ ] IAM user created with Access Key
- [ ] AWS CLI installed and `aws sts get-caller-identity` works
- [ ] GitHub repository created and cloned
- [ ] Docker Desktop installed and running
- [ ] Terraform installed
- [ ] kubectl installed
- [ ] S3 bucket for Terraform state created
- [ ] EC2 key pair downloaded to `~/.ssh/`
