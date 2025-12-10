# Healthletic-Backend Deployment Guide

## Project Overview

This project automates the build, security scanning, and deployment of the Healthletic Backend Flask API using **GitHub Actions CI/CD pipeline**. The application is deployed to an **ephemeral KIND cluster inside GitHub Actions runner**, using Helm for deployment.

The pipeline includes:

1. Docker image build with semantic versioning.
2. Security scan of Docker image using Trivy.
3. Push to Docker Hub.
4. Helm deployment to ephemeral KIND cluster.
5. Smoke tests to validate the deployment.
6. Automatic rollback if deployment fails.

---

## Prerequisites

### 1. GitHub Repository

* Repository name: `Healthletic-Backend`
* Branch: `main` (workflow triggers on push and pull request)

### 2. GitHub Secrets and Variables

Set the following **repository secrets**:

| Name                 | Description                                        |
| -------------------- | -------------------------------------------------- |
| `DOCKERHUB_USERNAME` | Your Docker Hub username                           |
| `DOCKERHUB_TOKEN`    | Docker Hub access token or password                |
| `IMAGE_REPO`         | Full image name, e.g., `vinay/healthletic-backend` |

---

### 3. Dockerfile

* Location: `Dockerfile` in the project root.
* Should install Python dependencies and expose the Flask app.

Example:

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY app/requirements.txt .
RUN pip install -r requirements.txt
COPY app/ .
EXPOSE 5000
CMD ["python", "app.py"]
```

---

### 4. Helm Chart

* Location: `helm/backend`
* Files:

  * `Chart.yaml`
  * `values.yaml`
  * `templates/deployment.yaml`
  * `templates/service.yaml`

Ensure:

* Deployment uses correct container port.
* Service name matches deployment (`healthletic-backend`).

---

## GitHub Actions Workflow

File location: `.github/workflows/deploy.yml`

### Workflow Steps:

1. **Checkout** – pulls repository code.
2. **Docker Build Environment** – sets up QEMU and Docker Buildx.
3. **Docker Hub Login** – authenticates for image push.
4. **Semantic Versioning** – uses latest git tag or defaults to `0.1.0`.
5. **Docker Image Build** – builds Flask API image.
6. **Security Scan** – uses Trivy to check for vulnerabilities.
7. **Push Image** – pushes image to Docker Hub.
8. **Setup KIND Cluster** – ephemeral Kubernetes cluster inside runner.
9. **Load Image into KIND** – ensures the image is available in KIND.
10. **Install kubectl & Helm** – for Kubernetes and Helm deployment.
11. **Helm Deploy** – deploys the application using Helm.
12. **Smoke Test & Debug** – waits for pods/services, checks logs, ensures API is reachable.
13. **Rollback** – automatic if deployment fails (`--atomic` flag).

---

## Manual Deployment Script

File: `deploy.sh`

Usage:

```bash
./deploy.sh --environment <env> --version <version> --image_registry <registry>
```

### Features:

* Validates input parameters.
* Uses `kubectl` and `helm` to deploy.
* Logs deployment steps to a file.
* Rolls back on failure.

---

## Smoke Tests

Inside workflow, smoke tests verify:

1. Deployment is ready:

```bash
kubectl rollout status deploy/healthletic-backend --timeout=120s
```

2. Service exists:

```bash
kubectl get svc healthletic-backend
```

3. API responds (from within the runner):

```bash
POD_NAME=$(kubectl get pod -l app=backend -o jsonpath="{.items[0].metadata.name}")
kubectl exec $POD_NAME -- curl -s http://localhost:5000/health
```

> These tests are done inside the ephemeral KIND cluster.

---

## Rollback Procedure

* Helm uses `--atomic` flag during deployment.
* If deployment fails:

  * Previous release is automatically restored.
* Check rollback history:

```bash
helm history healthletic-backend -n default
helm status healthletic-backend -n default
```

---

## Debugging & Troubleshooting

### Common Issues:

1. **Service not ready / Pod not running**

```bash
kubectl get pods -n default
kubectl logs deploy/healthletic-backend -n default
```

2. **Image not found / Docker push fails**

* Ensure `IMAGE_REPO` is correct.
* Verify `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`.

3. **Trivy scan fails**

* Ensure Docker image is built successfully.
* Use compatible Trivy version: `v0.30.0`.

4. **Helm chart issues**

* Verify `Chart.yaml` exists in `helm/backend`.
* Deployment and Service names should match.
* Use `helm lint ./helm/backend` to validate chart.

---

## Ephemeral KIND Cluster (Inside GitHub Actions)

### Benefits:

1. No need for persistent Kubernetes cluster.
2. Isolated, disposable environment for CI/CD.
3. Faster and safe for automated pipelines.
4. Clean environment for every run (no leftover resources).

### Limitation:

* Cannot access the deployed app outside the GitHub Actions runner.
* Testing must be done inside the workflow.

---

## Notes

* Always use semantic versioning for Docker images.
* Keep Helm charts consistent with container ports.
* Manual deployments are mainly for local KIND or EKS testing.
* All debugging logs are available in GitHub Actions logs.

---
