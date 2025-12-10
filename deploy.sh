#!/usr/bin/env bash
set -euo pipefail


LOGFILE="deploy.log"
exec > >(tee -a "$LOGFILE") 2>&1


print_usage() {
cat <<EOF
Usage: $0 --env <environment> --version <semver> --image_registry <registry/repo>
Example: ./deploy.sh --env staging --version 0.1.0 --image_registry youruser/healthletic-backend
EOF
}


# Simple argument parsing
while [[ $# -gt 0 ]]; do
key="$1"
case $key in
--env)
ENV="$2"; shift; shift;;
--version)
VERSION="$2"; shift; shift;;
--image_registry)
IMAGE_REGISTRY="$2"; shift; shift;;
--help)
print_usage; exit 0;;
*)
echo "Unknown argument $1"; print_usage; exit 1;;
esac
done


# Validate
if [[ -z "${ENV:-}" || -z "${VERSION:-}" || -z "${IMAGE_REGISTRY:-}" ]]; then
echo "ERROR: Missing required parameter."; print_usage; exit 2
fi


# Build image
IMAGE_TAG="${IMAGE_REGISTRY}:${VERSION}"


echo "Building $IMAGE_TAG"
docker build -t "$IMAGE_TAG" .


# Push
echo "Pushing $IMAGE_TAG"
docker push "$IMAGE_TAG"


# Helm deploy
RELEASE_NAME="backend-${ENV}"
CHART_PATH="./helm/backend"


function rollback_on_failure() {
echo "Rollback: upgrading to previous revision"
# Get last successful revision: helm history prints lines, last successful is the previous one with status deployed
helm rollback "$RELEASE_NAME" 1 || echo "Rollback command failed or no previous revision"
}


trap 'echo "Deployment failed — running rollback"; rollback_on_failure; exit 1' ERR


# Upgrade or install
helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
--set image.repository="${IMAGE_REGISTRY}" \
--set image.tag="${VERSION}"


# Simple smoke test
# Wait for pod ready
kubectl rollout status deployment/$(kubectl get deployment -l app=backend -o jsonpath='{.items[0].metadata.name}') --timeout=120s


# Port-forward test (run in background) and curl
kubectl port-forward svc/$(kubectl get svc -l app=backend -o jsonpath='{.items[0].metadata.name}') 8000:80 1>/dev/null 2>&1 &
PF_PID=$!
sleep 2
if curl -s -f http://localhost:8000/health >/dev/null; then
echo "Smoke tests passed"
else
echo "Smoke tests failed"
kill $PF_PID || true
exit 1
fi
kill $PF_PID || true


echo "Deployment succeeded"