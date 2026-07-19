# Troubleshooting

Real errors hit while building this pipeline, and the fix for each. Grouped by
the tool where the symptom shows up.

## Docker / ECR

### Pods stuck in `ImagePullBackOff` after a fresh deploy
**Cause:** the image was built on an Apple Silicon (arm64) Mac, but EKS worker
nodes are amd64. The manifest can't run a wrong-arch image.
**Fix:** always build for the node architecture:
```bash
docker build --platform linux/amd64 -t <repo> app/
```
The `Jenkinsfile` and GitHub Actions workflow both pin `--platform linux/amd64`.

### `docker push` denied / not authorized
**Cause:** ECR needs a login token; it expires.
**Fix:** re-run `aws ecr get-login-password | docker login --username AWS --password-stdin <registry>`. On the Jenkins EC2 this is keyless via the instance-profile IAM role - no stored keys.

## Jenkins

### Jenkins service crash-loops on startup
**Cause:** Jenkins requires Java 21+; the box had Java 17.
**Fix:** `jenkins-userdata.sh` installs `java-21-amazon-corretto`. If upgrading a
running box, install Java 21 and `systemctl restart jenkins`.

### GitHub webhook returns 502 / builds never trigger
**Cause:** the Jenkins security group didn't allow GitHub's webhook source IPs on
port 8080, so the webhook POST never reached Jenkins.
**Fix:** `github_webhook_cidrs` in `variables.tf` opens 8080 to GitHub's ranges.
If GitHub changes ranges, refresh from `https://api.github.com/meta`.

### Jenkins can't clone the repo over SSH (host key verification failed)
**Cause:** `github.com`'s host key wasn't trusted for the `jenkins` user.
**Fix:** userdata seeds `known_hosts` with `ssh-keyscan github.com`.

## Terraform

### `terraform destroy` hangs deleting the VPC
**Cause:** LoadBalancer services create AWS ELBs that Terraform doesn't own. If
the Service objects still exist, their ELBs hold ENIs in the VPC and block
deletion.
**Fix:** delete **both** LoadBalancer services before destroy - the app
(`svc/herovire-app`, ns `default`) and Grafana (ns `monitoring`). Then `terraform destroy`.

### EKS nodes / `dnf` can't reach the internet
**Cause:** missing egress rule on the security group.
**Fix:** `security-groups.tf` has an explicit egress-all rule
(`aws_vpc_security_group_egress_rule.jenkins_all`); without it outbound traffic is dropped.

### SSH or Jenkins UI suddenly unreachable
**Cause:** home ISP changed your public IP, so the `admin_ip_cidr` my-IP SG rule
no longer matches.
**Fix:** re-apply with the current IP:
`terraform apply -var="admin_ip_cidr=$(curl -s https://checkip.amazonaws.com)/32"`.

## EKS / Kubernetes

### EKS access-entry apply fails on the policy ARN
**Cause:** cluster access-entry policies use the EKS ARN namespace, not the IAM
one. `arn:aws:iam::aws:policy/...` is wrong here.
**Fix:** use `arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy`
(as in `eks.tf`).

## Monitoring (Prometheus / Grafana)

### ServiceMonitor scrapes nothing (app target missing in Prometheus)
**Cause:** the ServiceMonitor selects on a Service **label**, but the Service
only had the label under `selector`, not `metadata.labels`.
**Fix:** `k8s/service.yaml` sets `metadata.labels.app: herovire-app`.

### AlertManager pod stuck / not starting
**Cause:** it mounts the `alertmanager-smtp` secret (key `password`); if the
secret is missing the pod won't start.
**Fix:** create it first. For a real email use a Gmail app password; for a demo a
placeholder works (alert fires, no email sent):
```bash
kubectl create secret generic alertmanager-smtp -n monitoring --from-literal=password=placeholder
```

### `AppPodDown` alert doesn't fire when I delete the pod
**Cause:** the rule is `up{job="herovire-app"}==0`. Deleting all pods removes the
target entirely, so there's no `up==0` series to fire on.
**Fix (to demo):** make Ready pods unreachable on the scrape port instead (patch
the Service `targetPort` to a dead port), then revert. A more robust rule would
use `absent()` to catch a genuine pod-gone condition.
