---
marp: true
paginate: true
title: End-to-End DevOps CI/CD Pipeline on AWS
---

<!--
Presenter notes appear in comments like this throughout the deck.
To present: open in VS Code with the "Marp for VS Code" extension, or run
  marp docs/PRESENTATION.md --pdf      # or --pptx
Slides are separated by `---`.
-->

# End-to-End DevOps CI/CD Pipeline on AWS

**Herovire Capstone — Batch 15**
Rohit Gupta

From a `git push` to a running, monitored app on Kubernetes — fully automated.

<!--
30-second opener: "I built a complete CI/CD pipeline that takes application code
from GitHub all the way to a running, monitored service on AWS EKS, using the
standard DevOps toolchain — and I ran it end to end. I'll walk through the
architecture, each stage, a live demo, the problems I hit, and what I learned."
-->

---

## The Brief

**Goal:** take a web app from source code to production on AWS, automatically, the way a real DevOps team would.

Requirements:
- Containerize the app and build it in CI
- Provision all infrastructure as code (no clicking in the console)
- Deploy to a Kubernetes cluster
- Monitor it and alert on failure
- Keep it cheap and tear it down cleanly

**Evaluation:** Implementation 75% · Documentation 15% · Cost Optimization 10%

<!--
Emphasise "no clicking in the console" — everything is reproducible from code.
The three grading weights shaped my priorities: a working pipeline first,
clear docs, and disciplined cost control.
-->

---

## Architecture — one push, five stages

```
Developer
   │  git push
   ▼
GitHub ──► Jenkins (EC2) ──► Docker build ──► Amazon ECR
                                                  │
Terraform (VPC, EKS, IAM, ECR)  ◄── provisions ──┤
Ansible (configures the Jenkins host)             │
                                                  ▼
                              kubectl / rollout ──► Amazon EKS
                                                  │
                        Prometheus + Grafana ◄── scrapes /metrics
```

*(Full diagram on the next slide →)*

<!--
Trace the arrows with your finger while presenting. The key idea: code flows
left-to-right into ECR then onto EKS; Terraform stands the platform up
underneath; Ansible configures the CI host; Prometheus watches it all.
Region ap-south-1, single AWS account 376129434099.
-->

---

<!-- _paginate: false -->
![bg fit](architecture-diagram.svg)

<!--
The full architecture diagram. Walk it top-to-bottom: developer pushes to
GitHub, Jenkins builds the Docker image and pushes to ECR, Terraform has
provisioned the VPC/EKS/IAM underneath, kubectl rolls the image onto EKS, and
Prometheus/Grafana scrape and visualise it.
-->

---

## Tech stack at a glance

| Stage | Tool | Job |
|---|---|---|
| 1. Containerize + CI | **Docker + Jenkins** | Build image, push to ECR |
| 2. Infrastructure | **Terraform** | VPC, EKS, ECR, IAM (S3-backed state) |
| 3. Configuration | **Ansible** | Install/configure the Jenkins host |
| 4. Delivery | **kubectl → EKS** | Roll the image out to the cluster |
| 5. Monitoring | **Prometheus + Grafana** | Scrape metrics, dashboard, alerts |

App: a small **Flask** service — `/`, `/health`, `/metrics`.

<!--
This table is the spine of the whole talk — every stage slide that follows maps
back to one row. If asked "why these tools?": they're the industry-standard,
open, cloud-agnostic choices — the same stack a real team would use.
-->

---

## Stage 1 — Containerize & Build (Docker + Jenkins)

- **Dockerfile** packages the Flask app into a portable image
- **Jenkins on EC2** runs the pipeline (`Jenkinsfile`), stages:
  `Checkout → Build → ECR login → Tag & Push → Deploy → Smoke Test`
- Images pushed to **Amazon ECR** (private registry), tagged by build number
- Rollback baked in: a failed deploy or smoke test triggers `kubectl rollout undo`

<!--
Point out the Jenkinsfile has a failure post-step that emails me and rolls back.
Gotcha I hit: my Mac is arm64 but EKS nodes are amd64 — I build with
`--platform linux/amd64` or the pods hit ImagePullBackOff.
-->

---

## Stage 2 — Infrastructure as Code (Terraform)

Everything AWS is declared in `terraform/`:
- **VPC** with public/private subnets + NAT
- **EKS** cluster `herovire-eks` (2× t3.medium, private subnets)
- **ECR** repository (with lifecycle + `force_delete`)
- **IAM** roles, security groups, and OIDC provider

- **Remote state** in a versioned S3 bucket → safe, shareable, locked
- `terraform plan` is free — I only `apply` when actively working

<!--
IaC means the entire platform is reproducible: `apply` builds it, `destroy`
removes it, and the state file is the single source of truth. Remote state in S3
means I could hand this to a teammate and they'd get the identical environment.
-->

---

## Stage 3 — Configuration Management (Ansible)

- **Ansible** configures the Jenkins EC2 host from scratch:
  installs Jenkins, Docker, `kubectl`, and the AWS CLI
- Idempotent — re-running converges to the same state, never half-configured
- `Jenkinsfile.infra` lets Jenkins run **Terraform** itself (infra-as-a-job)

**Why both Terraform *and* Ansible?**
Terraform *provisions* the machines; Ansible *configures* what runs on them.

<!--
Common viva question — nail the Terraform-vs-Ansible distinction:
Terraform = provisioning (create the EC2/VPC/EKS). Ansible = configuration
(install and set up software on that EC2). They're complementary, not rivals.
-->

---

## Stage 4 — Continuous Delivery to EKS

- Jenkins runs `kubectl apply -f k8s/` then `kubectl set image` to the new tag
- Kubernetes objects: **Deployment** (2 replicas), **Service** (LoadBalancer), **HPA**
- `kubectl rollout status` gates the pipeline — deploy only "passes" when healthy
- App exposed publicly through an AWS **LoadBalancer**

- Liveness/readiness probes on `/health` keep only healthy pods in rotation

<!--
Show the running result: `kubectl get pods` = 2/2 Running, and the public LB URL
returning 200. The HPA can scale replicas on CPU (needs metrics-server, which I
install). The rollout-status gate is what makes it *continuous delivery* and not
just "fire and forget".
-->

---

## Stage 5 — Monitoring & Alerting (Prometheus + Grafana)

- **kube-prometheus-stack** (Helm) → Prometheus + Grafana + Alertmanager
- App instrumented with `prometheus-flask-exporter` → exposes `/metrics`
- A **ServiceMonitor** tells Prometheus to scrape the app
- **Grafana dashboard**: request rate — `rate(flask_http_request_total[1m])`
- **Alert**: `AppPodDown` fires when the app's scrape target is down

<!--
Observability closes the loop: it's not "deployed" until I can see it's healthy.
Honest caveat to mention: my AppPodDown alert fires when a live target fails its
scrape, not on a scale-to-zero (the target just disappears) — an absent()-based
rule would be the improvement.
-->

---

## Stage 6 — Testing & Quality Gates

- `tests/smoke_test.sh` — hits the LB, asserts `/` and `/health` return **200**
- `tests/infra_test.sh` — asserts nodes **Ready**, pods **Running**, LB provisioned
- Smoke test is a **Jenkins stage** — a non-200 **fails the build** and rolls back
- Full from-scratch deploy → test → destroy verified end to end

<!--
This is the "definition of done" for the pipeline: a machine, not me, decides if
a deploy is good. The scripts exit non-zero on failure so CI can gate on them.
I verified the whole cycle live: apply → tests pass → destroy, back to ~$0.
-->

---

## Bonus — Modern GitOps (GitHub Actions + ArgoCD)

I added a **push-CI + pull-CD** alternative and ran it **live**:

- **GitHub Actions** builds the image and pushes to ECR — authenticating with
  **OIDC** (short-lived creds, *no* AWS keys stored in GitHub)
- CI then bumps the image tag in `k8s/deployment.yaml` and commits it back
- **ArgoCD** watches git and reconciles the cluster to match (`selfHeal`, `prune`)

**Result:** one `git push` → app went **v1 → v2** automatically, no `kubectl`.

<!--
This is the differentiator. Contrast with Jenkins: Jenkins *pushes* changes to
the cluster; ArgoCD *pulls* from git — git becomes the single source of truth.
OIDC = keyless auth, the modern security best practice. I have this working, not
just written.
-->

---

## Live Demo

1. Show the app responding (**v1**) through its LoadBalancer
2. `git push` a one-line change to the app
3. **GitHub Actions** tab — pipeline goes green (OIDC → build → push → bump)
4. **ArgoCD UI** — app tile flips `OutOfSync` → `Synced`, new pods roll
5. Refresh the app → now **v2**
6. **Self-heal:** `kubectl scale --replicas=1` → ArgoCD reverts it to 2 in ~8s

<!--
Backup plan if live fails: I have screenshots of each step. Talking point for
step 6: deleting a pod is *Kubernetes* self-healing (ReplicaSet); reverting my
manual scale is *ArgoCD* self-healing (drift from git). Two layers.
-->

---

## Cost Optimization (10% of grade)

- Running cost ≈ **$0.25–0.30/hr** (EKS control plane + 2 nodes + NAT + LB)
- `terraform plan` and all code work is **free** — only `apply` costs money
- **Right-sized**: 2× t3.medium, 3-day metrics retention, single NAT
- **Destroy after every session** → a full build→verify→destroy cycle ≈ **$0.25**
- ECR lifecycle policy expires untagged images automatically

<!--
Cost discipline was a deliberate practice, not an afterthought. The habit:
write and plan for free, apply only while actively demoing, always destroy.
The remote state + IaC make tearing down and rebuilding cheap and safe.
-->

---

## Challenges I hit (and fixed)

- **arm64 vs amd64** — Mac builds arm64, nodes are amd64 → `--platform linux/amd64`
- **Orphaned LoadBalancers blocked VPC deletion** → delete Services *before* destroy
- **ServiceMonitor scraped nothing** → Service needed a `labels.app` (not just selector)
- **ArgoCD CRD too large** for client-side apply → `kubectl apply --server-side`
- **ArgoCD vs teardown** → `selfHeal` recreated deleted pods → remove the App first
- **Git drift** — ArgoCD caught that `main` was behind local & pointing at an old account

<!--
Pick 2-3 to tell as stories. The ArgoCD-caught-drift one is great: it *proved*
GitOps works — ArgoCD faithfully deployed what git said, which surfaced that my
remote was stale. The tool caught a mistake I'd have missed.
-->

---

## Key Learnings

- **Infrastructure as Code** — reproducible, reviewable, disposable environments
- **Provision vs configure** — Terraform and Ansible do different jobs
- **Push vs pull delivery** — Jenkins pushes; ArgoCD pulls from git
- **Keyless auth (OIDC)** — short-lived creds beat stored secrets
- **Observability** — a deploy isn't done until you can *see* it's healthy
- **Cost discipline** — plan free, apply briefly, always tear down

<!--
Frame these as things I'd carry into a real job, not just facts I memorised.
The biggest shift: thinking of infrastructure as code and git as the source of
truth for *everything* — app and platform alike.
-->

---

## Summary

- Built a complete pipeline: **GitHub → Jenkins → Docker → ECR → Terraform → Ansible → EKS → Prometheus/Grafana**
- Added and **ran live** a modern **GitOps** path (GitHub Actions + ArgoCD)
- Tested, documented, cost-controlled, and fully reproducible

**One `git push` → a running, monitored app on Kubernetes.**

## Thank you — questions?

<!--
Close with the one-liner. Have the repo, the architecture diagram, and the
Actions/ArgoCD screenshots ready to pull up for questions.
-->
