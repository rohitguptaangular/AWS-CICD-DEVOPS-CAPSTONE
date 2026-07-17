# Modern Alternative to Jenkins: GitHub Actions + ArgoCD

The graded pipeline uses **Jenkins** for both CI (build/push) and CD (deploy to
EKS). This document shows how the same pipeline looks with a modern,
cloud-native toolchain, and why teams increasingly choose it.

## The split

Jenkins does two very different jobs in one place. The modern stack separates them:

| Concern | This project (Jenkins) | Modern alternative |
|---|---|---|
| CI — build image, push to ECR | `Jenkinsfile` build stages | **GitHub Actions** (`.github/workflows/ci.yml`) |
| CD — deploy to Kubernetes | `Jenkinsfile` deploy stage (`kubectl apply`) | **ArgoCD** (`argocd/application.yaml`) |

## Push vs. pull — the core difference

**Jenkins is push-based and imperative.** Jenkins holds credentials into the
cluster and *reaches in* to run `kubectl apply` / `kubectl set image`. The
cluster is a passive target; whatever Jenkins last ran is the state. If someone
changes the cluster by hand, nothing corrects it.

**ArgoCD is pull-based and declarative (GitOps).** ArgoCD runs *inside* the
cluster, watches the `k8s/` manifests in git, and continuously reconciles the
cluster to match. Git is the single source of truth:
- `selfHeal: true` — manual drift is automatically reverted to the git state.
- `prune: true` — resources deleted from git are deleted from the cluster.
- No external system needs cluster credentials — the agent is already inside.

## Credentials — OIDC vs. stored secrets

The Jenkins EC2 uses an **instance-profile IAM role** for keyless AWS auth, which
is good. GitHub Actions goes further with **OIDC federation**
(`terraform/github-oidc.tf`): each workflow run exchanges a short-lived GitHub
token for temporary AWS credentials scoped to this repo. There is **no long-lived
AWS key stored in GitHub at all** — the role trusts `repo:<owner>/<name>:*`.

## Trade-offs (the honest version)

**Why the modern stack wins for many teams:**
- No Jenkins server to run, patch, or pay for (~$0.03/hr EC2 here → $0 with Actions' hosted runners).
- GitOps gives an auditable git history of every deploy and automatic drift correction.
- Short-lived OIDC credentials instead of stored secrets.

**Why Jenkins is still a reasonable choice here:**
- One tool, one place — simpler mental model for a learner or a small team.
- Full control over the build environment (self-hosted).
- Mature plugin ecosystem; no dependency on GitHub-hosted runners.

## Running the alternative

1. `terraform apply` creates the GitHub OIDC provider + CI role. Copy the
   `github_actions_role_arn` output into a GitHub Actions **repository variable**
   named `AWS_ROLE_ARN`.
2. Push a change under `app/` → GitHub Actions builds and pushes to ECR via OIDC.
3. Install ArgoCD in the cluster and apply `argocd/application.yaml`:
   ```
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   kubectl apply -f argocd/application.yaml
   ```
   ArgoCD then syncs `k8s/` and keeps the app reconciled to git.

## Note on true GitOps image tags

`k8s/deployment.yaml` uses the `:latest` tag, so ArgoCD redeploys when `latest`
moves. In strict GitOps the CI job would write the **new image tag back into git**
(e.g. update the deployment manifest), so every deployed version is recorded in
git history rather than hidden behind a floating tag. That is the natural next
step if this pipeline went to production.
