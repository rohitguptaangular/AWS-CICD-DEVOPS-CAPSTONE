#!/usr/bin/env bash
# Infrastructure test: verify the EKS cluster and app workload are healthy.
# A lightweight, dependency-free alternative to Terratest for this capstone.
#
# Usage: ./infra_test.sh
# Assumes kubeconfig already points at the cluster
#   (aws eks update-kubeconfig --region ap-south-1 --name herovire-eks).
set -euo pipefail

fail=0
note() { echo "-> $*"; }
pass() { echo "PASS: $*"; }
bad()  { echo "FAIL: $*"; fail=1; }

# 1. Every node must be Ready.
note "Checking nodes are Ready ..."
not_ready=$(kubectl get nodes --no-headers | awk '$2 != "Ready" {print $1}')
if [[ -z "$not_ready" ]]; then
  pass "all nodes Ready ($(kubectl get nodes --no-headers | wc -l | tr -d ' ') total)"
else
  bad "nodes not Ready: $not_ready"
fi

# 2. App pods must be Running.
note "Checking app pods are Running ..."
total=$(kubectl get pods -l app=herovire-app --no-headers 2>/dev/null | wc -l | tr -d ' ')
running=$(kubectl get pods -l app=herovire-app --no-headers 2>/dev/null | awk '$3 == "Running"' | wc -l | tr -d ' ')
if [[ "$total" -gt 0 && "$total" == "$running" ]]; then
  pass "app pods Running ($running/$total)"
else
  bad "app pods Running $running/$total"
fi

# 3. Service must have LoadBalancer ingress assigned.
note "Checking LoadBalancer is provisioned ..."
lb=$(kubectl get svc herovire-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
if [[ -n "$lb" ]]; then
  pass "LoadBalancer hostname: $lb"
else
  bad "no LoadBalancer hostname on service/herovire-app"
fi

[[ "$fail" -eq 0 ]] && echo "Infra test passed." || { echo "Infra test FAILED."; exit 1; }
