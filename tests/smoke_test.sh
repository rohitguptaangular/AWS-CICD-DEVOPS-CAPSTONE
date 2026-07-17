#!/usr/bin/env bash
# Smoke test: verify the deployed app answers HTTP 200 through its LoadBalancer.
#
# Usage:
#   ./smoke_test.sh                 # discover the LB URL via kubectl
#   ./smoke_test.sh http://host     # test an explicit base URL
#   APP_URL=http://host ./smoke_test.sh
#
# Exits non-zero on any failed check so a CI stage can fail the build.
set -euo pipefail

SERVICE="herovire-app"
NAMESPACE="default"
RETRIES="${RETRIES:-30}"     # LB provisioning + DNS can take a few minutes
SLEEP="${SLEEP:-10}"

# Resolve the base URL: explicit arg/env wins, otherwise ask kubectl for the ELB hostname.
BASE_URL="${1:-${APP_URL:-}}"
if [[ -z "$BASE_URL" ]]; then
  echo "No URL given — discovering LoadBalancer hostname for service/$SERVICE ..."
  host=""
  for i in $(seq 1 "$RETRIES"); do
    host=$(kubectl get svc "$SERVICE" -n "$NAMESPACE" \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
    [[ -n "$host" ]] && break
    echo "  [$i/$RETRIES] LB hostname not assigned yet; waiting ${SLEEP}s ..."
    sleep "$SLEEP"
  done
  [[ -z "$host" ]] && { echo "FAIL: LoadBalancer hostname never appeared."; exit 1; }
  BASE_URL="http://${host}"
fi

echo "Target: $BASE_URL"

# curl the given path until it returns the expected status or we run out of retries.
check() {
  local path="$1" expect="$2" code=""
  for i in $(seq 1 "$RETRIES"); do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "${BASE_URL}${path}" || echo "000")
    if [[ "$code" == "$expect" ]]; then
      echo "PASS: GET ${path} -> ${code}"
      return 0
    fi
    echo "  [$i/$RETRIES] GET ${path} -> ${code} (want ${expect}); retrying in ${SLEEP}s ..."
    sleep "$SLEEP"
  done
  echo "FAIL: GET ${path} -> ${code} (want ${expect}) after ${RETRIES} tries"
  return 1
}

check "/" 200
check "/health" 200

echo "Smoke test passed."
