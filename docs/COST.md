# Cost Analysis

Cost optimization is 10% of the grade. The guiding rule for this project:
**writing and `terraform plan` are free; only `terraform apply` costs money - so
apply only when actively working, and `terraform destroy` after every session.**

## What costs money when the stack is up

Approximate `ap-south-1` on-demand rates for the running footprint:

| Resource | Qty | ~Cost/hr | Notes |
|---|---|---|---|
| EKS control plane | 1 | $0.10 | flat per-cluster fee |
| Worker nodes (t3.medium) | 2 | ~$0.09 | $0.0448/hr each |
| Jenkins EC2 (t3.medium) | 1 | ~$0.045 | |
| NAT Gateway | 1 | ~$0.045 | + data processing |
| Classic LB (app + Grafana) | 1-2 | ~$0.025 ea | one per LoadBalancer service |
| EBS / EIP / ECR storage | - | negligible | pennies |
| **Total running** | | **~$0.25-0.30/hr** | |

## What a full work cycle costs

A complete **apply → verify → destroy** cycle takes roughly an hour of runtime,
so **≈ $0.25-0.30 per session**. Leaving it running is what gets expensive: the
same stack left up 24/7 is **~$180-210/month** (EKS ~$73 + nodes ~$65 + NAT ~$32
+ Jenkins ~$33 + LBs). Discipline on teardown is the single biggest saving.

## How this project keeps cost near zero

- **Destroy after every session** - back to ~$0 between work sessions (the
  state bucket + key pair are the only things left, and they're free).
- **Right-sized instances** - `t3.medium` everywhere; nodes fixed at 2
  (`node_desired_size = 2`), not an oversized default.
- **Single NAT Gateway** rather than one per AZ.
- **ECR lifecycle policy** expires untagged images so storage doesn't grow.
- **Free-tier-friendly workflow** - all authoring and `plan` runs cost nothing.

## Verifying actual spend

Check **AWS Cost Explorer** (Billing console) after a session - filter by the
`herovire` tag applied via Terraform default tags. Because the stack is destroyed
between sessions, month-to-date should stay in the low single-digit dollars.
