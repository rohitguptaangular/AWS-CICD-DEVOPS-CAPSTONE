# Learning Notes

How I learned the stack for this capstone: the order I took the tools in, roughly how long each actually took me, and what I'd tell someone starting the same project. The order matters more than the pace - each tool assumes the one before it.

```
Linux + Git -> Docker -> AWS basics -> Jenkins -> Terraform -> Ansible -> Kubernetes -> Prometheus/Grafana
```

## Linux + Git (2-3 days, mostly refresher)

Nothing in this project works without being comfortable on a shell over SSH. The commands that came up constantly:

```bash
ssh -i ~/.ssh/key.pem ec2-user@<ip>   # half my time was spent inside EC2 boxes
systemctl status/restart jenkins      # debugging the Jenkins service
tail -f /var/log/...                  # watching logs
chmod 400 key.pem                     # SSH refuses world-readable keys
```

Git-wise the project only needed the basics (clone, branch, add/commit/push, PRs), but since the webhook fires on every push, git IS the deploy button here. `git log --oneline` became my deployment history.

## Docker (3-4 days)

I started by just running things (`docker pull nginx`, `docker run -p 8080:80 nginx`) before writing the Dockerfile for the Flask app in `app/`. The mental model that made it click: an image is a blueprint, a container is a running instance of it.

What I'd flag for the next person: build-time vs run-time (RUN vs CMD) confused me at first, and cross-architecture builds will bite anyone on an M-series Mac (`--platform linux/amd64`, see TROUBLESHOOTING.md).

## AWS basics (3-5 days)

Before touching Terraform I made the core pieces by hand in the console once, which I'm glad I did - it made the Terraform code readable instead of magic. The minimum set: EC2 (instance types, key pairs, security groups), VPC (subnets, IGW, NAT), S3, and above all IAM.

IAM is the one worth slowing down for. Users vs roles vs policies, and the rule the whole project follows: never hardcode AWS keys, always attach a role. Every keyless auth trick in this pipeline (Jenkins to ECR, GitHub Actions OIDC) builds on that.

## Jenkins (4-5 days)

Path I took: install on EC2, get the UI up on :8080, one throwaway freestyle job, then straight to a Jenkinsfile in the repo. The real Jenkinsfiles are at the repo root; they're a better reference than any tutorial snippet at this point.

Time sinks to expect: plugin setup, the credentials store, and getting the GitHub webhook to actually reach the box (security group rules - that one's in the troubleshooting doc).

## Terraform (5-7 days)

I learned it in the same order the repo's git history shows: one S3 bucket first to learn init/plan/apply/destroy, then variables and outputs, then remote state, then the real infrastructure (VPC, EC2, ECR, EKS) piece by piece across Sprint 2.

The concept that matters most: state. Terraform only knows what it created through the state file, so losing it means Terraform forgets your infrastructure exists. Remote state in S3 (`terraform/backend.tf`) fixes that and took me under an hour to set up - do it before creating anything expensive.

## Ansible (3-4 days)

The quickest tool of the bunch to become productive in. Inventory file, playbook, `ansible -m ping` to prove connectivity, then `ansible-playbook`. The playbook in `ansible/` (loop, handler, conditional install) covers most of the syntax the project needs.

The idea to internalize is idempotency: `state: present` means "make sure it's installed", so re-running a playbook is always safe. I verified this on a live EC2 in Sprint 3, and it's what makes the infra pipeline re-runnable.

## Kubernetes (7-10 days, the big one)

By far the steepest learning curve, and I'd budget for that. My order: Pods and Deployments first, then Services (and what `type: LoadBalancer` does on AWS), then probes, then HPA. The manifests I actually wrote are in `k8s/` and are commented; I practiced on a local/browser cluster before pointing anything at EKS since EKS bills by the hour.

The model that eventually clicked: a Pod is a running process, a Deployment keeps the right number of them alive, a Service is the stable address in front of them, and the HPA turns the replica count into a function of load. The kubectl verbs I use daily: apply, get, describe, logs, exec.

EKS adds its own layer on top (kubeconfig via `aws eks update-kubeconfig`, aws-auth, IAM) - that's Sprint 4 territory and much easier once plain Kubernetes makes sense.

## Prometheus + Grafana (3-4 days)

Installed as one Helm chart (kube-prometheus-stack), which brings Prometheus, Grafana, and the Kubernetes dashboards in a single step - the exact command is in `docs/SETUP_GUIDE.md`. Most of my time went into PromQL and into getting the app's ServiceMonitor scraping correctly.

The PromQL I actually used:

```promql
rate(container_cpu_usage_seconds_total[5m])                # CPU per pod
increase(kube_pod_container_status_restarts_total[1h])     # restart alerting
rate(http_requests_total[5m])                              # app request rate
```

## Resources I actually used

| Tool | Resource |
|---|---|
| Docker | [Play with Docker](https://labs.play-with-docker.com/) |
| Kubernetes | [Killercoda](https://killercoda.com/) browser playground |
| Terraform | [HashiCorp AWS getting-started](https://developer.hashicorp.com/terraform/tutorials/aws-get-started) |
| Jenkins | [jenkins.io tutorials](https://www.jenkins.io/doc/tutorials/) |
| Ansible | [Ansible getting started](https://docs.ansible.com/ansible/latest/getting_started/) |
| AWS | [AWS Skill Builder](https://explore.skillbuilder.aws/) free tier |
| Prometheus | [Prometheus getting started](https://prometheus.io/docs/prometheus/latest/getting_started/) |
