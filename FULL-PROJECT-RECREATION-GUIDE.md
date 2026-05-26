# Full Project Recreation Guide — DevSecOps GKE Autopilot Platform

> **Target:** Recreate the entire DevSecOps platform from scratch on a **new GCP project**.
> **Cluster type:** GKE Autopilot (regional, VPC-native)
> **Region:** `europe-west9` (Paris)
> **GitHub Repo:** `MaramRezgui1/PFE_project`
> **Estimated time:** 30–45 minutes (excluding Terraform provisioning)

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Phase 1 — GCP Project Setup](#2-phase-1--gcp-project-setup)
3. [Phase 2 — Terraform Infrastructure](#3-phase-2--terraform-infrastructure)
4. [Phase 3 — Connect to GKE Cluster](#4-phase-3--connect-to-gke-cluster)
5. [Phase 4 — Deploy Application](#5-phase-4--deploy-application)
6. [Phase 5 — Install Argo CD](#6-phase-5--install-argo-cd)
7. [Phase 6 — Playwright E2E Tests](#7-phase-6--playwright-e2e-tests)
8. [Phase 7 — Install Prometheus & Grafana (Optional)](#8-phase-7--install-prometheus--grafana-optional)
9. [Phase 8 — Configure GitHub Actions CI/CD](#9-phase-8--configure-github-actions-cicd)
10. [Phase 9 — Validation & Smoke Tests](#10-phase-9--validation--smoke-tests)
11. [Improvements & Recommendations](#11-improvements--recommendations)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Prerequisites

### Tools to install locally

| Tool | Version | Install |
|------|---------|---------|
| `gcloud` CLI | Latest | https://cloud.google.com/sdk/docs/install |
| `terraform` | >= 1.5 | https://developer.hashicorp.com/terraform/install |
| `kubectl` | >= 1.28 | `gcloud components install kubectl` |
| `helm` | >= 3.12 | https://helm.sh/docs/intro/install/ |
| `docker` | Latest | https://docs.docker.com/get-docker/ |
| `node` / `npm` | >= 20 | https://nodejs.org/ |

### GCP requirements

- A GCP project with **billing enabled**
- Owner or Editor role on the project
- Sufficient quotas in `europe-west9` for GKE Autopilot

---

## 2. Phase 1 — GCP Project Setup

### 2.1 Authenticate and set project

```bash
gcloud auth login
gcloud config set project maram-pfe-495314
gcloud config set compute/region europe-west9
```

### 2.2 Verify billing is enabled

```bash
gcloud billing projects describe maram-pfe-495314
```

### 2.3 Enable base APIs

```bash
gcloud services enable \
  serviceusage.googleapis.com \
  cloudresourcemanager.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  --project=maram-pfe-495314
```

### 2.4 Create Artifact Registry repository (if not exists)

```bash
gcloud artifacts repositories create sopra-repo \
  --repository-format=docker \
  --location=europe-west9 \
  --description="Docker images for login-page app" \
  --project=maram-pfe-495314
```

### 2.5 Create a Terraform deployer service account key

```bash
# Create the service account
gcloud iam service-accounts create terraform-deployer \
  --display-name="Terraform Deployer"

# Grant owner role (for PFE simplicity; use least-privilege in production)
gcloud projects add-iam-policy-binding maram-pfe-495314 \
  --member="serviceAccount:terraform-deployer@maram-pfe-495314.iam.gserviceaccount.com" \
  --role="roles/owner"

# Create and download key
gcloud iam service-accounts keys create ~/.config/gcloud/terraform-deployer-key.json \
  --iam-account=terraform-deployer@maram-pfe-495314.iam.gserviceaccount.com
```

---

## 3. Phase 2 — Terraform Infrastructure

Terraform provisions: VPC, subnet, GKE Autopilot cluster, IAM service accounts, WIF pool/provider, Workload Identity bindings.

### 3.1 Review/Update `terraform.tfvars`

```hcl
# terraform/terraform.tfvars
project_id  = "maram-pfe-495314"
github_repo = "MaramRezgui1/PFE_project"
```

### 3.2 Initialize and apply Terraform

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

> ⏱ This takes **10–15 minutes** (GKE Autopilot cluster creation is the slowest part).

### 3.3 Get outputs for GitHub Secrets

After apply succeeds, get the values you'll need:

```bash
terraform output -raw wif_provider
terraform output -raw wif_service_account
```

### 3.4 What Terraform creates

| Resource | Name | Purpose |
|----------|------|---------|
| VPC | `maram-vpc` | Isolated network |
| Subnet | `maram-subnet` (10.0.0.0/22) | Node IPs + secondary ranges for pods/services |
| GKE Autopilot | `maram-cluster-terraform` | Kubernetes cluster (fully managed nodes) |
| WIF Pool | `github-actions-pool` | Workload Identity Federation pool for GitHub Actions |
| WIF Provider | `github-provider` | OIDC provider linking GitHub to GCP |
| Service Account | `github-actions-cicd` | Push images + deploy to GKE |
| Service Account | `github-actions-sa` | CI/CD with Cloud Run + GKE + AR (used by WIF) |
| Service Account | `gke-app-sa` | Pods pull images via Workload Identity |
| IAM Bindings | Various | AR reader/writer, GKE developer, WIF user |

---

## 4. Phase 3 — Connect to GKE Cluster

> ⚠️ Use literal values — no env vars needed.

```bash
gcloud container clusters get-credentials maram-cluster-terraform \
  --region europe-west9 \
  --project maram-pfe-495314
```

### Verify connection

```bash
kubectl get nodes
# Autopilot: nodes appear dynamically when workloads are scheduled

kubectl cluster-info
```

---

## 5. Phase 4 — Deploy Application

### 5.1 Deploy the K8s manifest

The manifest at `terraform/k8s-deployment.yaml` includes:
- Namespace `sopra-hr`
- Deployment `login-page` (1 replica, image from Artifact Registry)
- Service `login-page-service` (LoadBalancer on port 80 → 8080)

```bash
kubectl apply -f terraform/k8s-deployment.yaml
```

### 5.2 Verify deployment and get external IP

```bash
kubectl get pods -n sopra-hr
kubectl get svc -n sopra-hr

# Wait for external IP (takes 1-3 minutes)
kubectl get svc login-page-service -n sopra-hr -w
```

Once the EXTERNAL-IP appears, open `http://<EXTERNAL-IP>` in your browser.

---

## 6. Phase 5 — Install Argo CD

Argo CD watches your GitHub repo and auto-deploys when `terraform/k8s-deployment.yaml` changes.

### 6.1 Install Argo CD

```bash
kubectl create namespace argocd

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 6.2 Wait for Argo CD to be ready

```bash
kubectl rollout status deploy/argocd-server -n argocd --timeout=300s
```

### 6.3 Get the initial admin password

```bash
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "Argo CD admin password: ${ARGOCD_PASSWORD}"
```

### 6.4 Access Argo CD Dashboard

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443 &
echo "Argo CD UI: https://localhost:8081"
echo "Username: admin"
echo "Password: ${ARGOCD_PASSWORD}"
```

### 6.5 Register the GitOps Application

```bash
kubectl apply -f argocd/application.yaml
```

This Application CR tells Argo CD to:
- Watch repo: `https://github.com/MaramRezgui1/PFE_project`
- Branch: `main`
- Path: `terraform/` (only `k8s-deployment.yaml`)
- Deploy to namespace: `sopra-hr`
- Auto-sync with pruning and self-heal enabled

### 6.6 Verifuy Argo CD sync status

```bash
kubectl get applications -n argocd
# Expected: login-page   Synced   Healthy
```

---

## 7. Phase 6 — Playwright E2E Tests

Playwright provides end-to-end browser testing against the deployed application. Tests run locally during development and as a **Kubernetes Job on GKE** in the CI/CD pipeline.

### 7.1 Install Playwright locally

```bash
npm install -D @playwright/test
npx playwright install --with-deps chromium
```

### 7.2 Project structure

| File | Purpose |
|------|---------|
| `playwright.config.ts` | Playwright configuration (baseURL from `BASE_URL` env var, default `http://localhost:8080`) |
| `e2e/login.spec.ts` | 5 E2E test cases |
| `Dockerfile.playwright` | Docker image for running tests in containers (based on `mcr.microsoft.com/playwright`) |
| `k8s/playwright-job.yaml` | K8s Job manifest to run tests on GKE |

### 7.3 Test cases

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | **Login form display** | All fields (identifiant, mot de passe, langue) and submit button are visible |
| 2 | **Login success** | Valid credentials (`TNEEIN01`/`4YOU`) → redirect to `/dashboard`, user info displayed |
| 3 | **Login failure** | Invalid credentials → error toast "Erreur de connexion" appears |
| 4 | **Dashboard protection** | Accessing `/dashboard` without auth shows no protected content |
| 5 | **Logout** | After login, clicking logout returns to login page |

### 7.4 Run tests locally

```bash
# Start the app locally (after building)
npm run build
npx vite preview --port 8080 &

# Run Playwright tests
npm run test:e2e

# Or with UI mode for debugging
npm run test:e2e:ui
```

### 7.5 Available npm scripts

```json
{
  "test:e2e": "playwright test",
  "test:e2e:ui": "playwright test --ui",
  "test:e2e:ci": "playwright test --project=chromium --reporter=junit"
}
```

### 7.6 Playwright Docker image

The `Dockerfile.playwright` builds a container that runs tests against any target URL:

```bash
# Build the Playwright test image
docker build -f Dockerfile.playwright -t playwright-tests .

# Run tests against a local app
docker run --rm --network=host -e BASE_URL=http://localhost:8080 playwright-tests

# Run tests against GKE service (from within the cluster)
docker run --rm -e BASE_URL=http://login-page-service.sopra-hr.svc.cluster.local playwright-tests
```

### 7.7 K8s Job for GKE execution

The `k8s/playwright-job.yaml` defines a Kubernetes Job that runs inside the cluster, targeting the app via its internal service DNS:

```yaml
# Key configuration:
env:
  - name: BASE_URL
    value: "http://login-page-service.sopra-hr.svc.cluster.local"
```

Run manually on GKE:
```bash
kubectl apply -f k8s/playwright-job.yaml
kubectl wait --for=condition=complete job/playwright-e2e-tests -n sopra-hr --timeout=300s
kubectl logs job/playwright-e2e-tests -n sopra-hr
```

### 7.8 CI/CD integration

The pipeline adds two stages after the image push:

| Stage | Job Name | What it does |
|-------|----------|--------------|
| 5B | 🎭 **Build Playwright Image** | Builds and pushes `playwright-tests` image to Artifact Registry |
| 5C | 🎭 **Playwright E2E Tests** | Runs tests as a K8s Job on GKE after ArgoCD sync confirms healthy deployment |

The E2E tests act as a **gate before OWASP ZAP** — if tests fail, ZAP scan won't run.

---

## 8. Phase 7 — Install Prometheus & Grafana (Optional)

### 8.1 Add Helm repo and install

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace observability

helm upgrade --install kube-prom prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --set grafana.adminPassword="DevOps2025!" \
  --wait --timeout 10m
```

### 8.2 Access Grafana

```bash
kubectl port-forward svc/kube-prom-grafana -n observability 3000:80 &
echo "Grafana: http://localhost:3000"
echo "Username: admin"
echo "Password: DevOps2025!"
```

---

## 9. Phase 8 — Configure GitHub Actions CI/CD

The pipeline uses **Workload Identity Federation (WIF)** for keyless authentication — no service account key files needed.

### 9.1 Get the secret values from Terraform

```bash
cd terraform
echo "WIF_PROVIDER = $(terraform output -raw wif_provider)"
echo "WIF_SERVICE_ACCOUNT = $(terraform output -raw wif_service_account)"
```

Expected output:
```
WIF_PROVIDER = projects/770541080410/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider
WIF_SERVICE_ACCOUNT = github-actions-sa@maram-pfe-495314.iam.gserviceaccount.com
```

### 9.2 Set GitHub repository secrets

Go to: `https://github.com/MaramRezgui1/PFE_project/settings/secrets/actions`

Click **"New repository secret"** for each:

| Secret Name | Value |
|-------------|-------|
| `WIF_PROVIDER` | `projects/770541080410/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider` |
| `WIF_SERVICE_ACCOUNT` | `github-actions-sa@maram-pfe-495314.iam.gserviceaccount.com` |

> ✅ Only **2 secrets** needed. No JSON key files.

### 9.3 Pipeline stages (`.github/workflows/deploy.yml`)

The workflow triggers on push to `main` (except changes to `terraform/k8s-deployment.yaml` to avoid loops):

| Stage | Job Name | What it does |
|-------|----------|--------------|
| 1 | 🔨 **Build** | Builds Docker image, saves as artifact |
| 2 | 🔍 **Trivy Scan** | Scans image for CVEs (CRITICAL/HIGH). Uploads SARIF to GitHub Security + HTML report |
| 3 | 📦 **Push** | Pushes image to Artifact Registry (only if Trivy passes) |
| 3B | ☁️ **Cloud Run Deploy** | Deploys to Cloud Run (managed serverless) |
| 4 | ✏️ **Update Manifest** | Updates image tag in `terraform/k8s-deployment.yaml` and pushes commit |
| 5 | 🔄 **ArgoCD Sync** | Triggers Argo CD sync and waits for healthy deployment |
| 5B | 🎭 **Build Playwright Image** | Builds and pushes Playwright test Docker image to Artifact Registry |
| 5C | 🎭 **Playwright E2E Tests** | Runs E2E tests as K8s Job on GKE (gate before ZAP) |
| 6 | 🛡️ **OWASP ZAP** | Runs DAST scan against the live app via port-forward |

### 9.4 How it works (GitOps flow)

```
Developer pushes code to `main`
        │
        ▼
┌──────────────────────────────────┐
│  GitHub Actions CI                │
│                                  │
│  1. Build Docker image            │
│  2. Trivy scan (block if CVE)    │
│  3. Push to Artifact Registry     │
│  3B. Deploy to Cloud Run          │
│  4. Update k8s-deployment.yaml    │
│  5. Trigger ArgoCD sync           │
│  5B. Build Playwright test image  │
│  5C. Run Playwright E2E tests     │
│  6. OWASP ZAP DAST scan          │
└──────────┬───────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│  Argo CD (in-cluster)             │
│  - Detects manifest change        │
│  - Syncs new image to GKE         │
│  - Rolls out new pods             │
└──────────────────────────────────┘
```

### 9.5 Required files in your repo

| File | Purpose |
|------|---------|
| `.github/workflows/deploy.yml` | The CI/CD pipeline definition |
| `.zap/rules.tsv` | ZAP scan rules (ignore false positives) |
| `terraform/k8s-deployment.yaml` | K8s manifest (updated by pipeline) |
| `argocd/application.yaml` | Argo CD Application CR |
| `Dockerfile` | Multi-stage build (Node → Nginx) |
| `Dockerfile.playwright` | Playwright test runner image |
| `playwright.config.ts` | Playwright configuration |
| `e2e/login.spec.ts` | E2E test cases (5 tests) |
| `k8s/playwright-job.yaml` | K8s Job for running E2E tests on GKE |

### 9.6 Trigger the pipeline

```bash
# Make any code change and push
git add .
git commit -m "feat: trigger CI/CD pipeline"
git push origin main
```

Then watch: `https://github.com/MaramRezgui1/PFE_project/actions`

---

## 10. Phase 9 — Validation & Smoke Tests

### 10.1 Application health

```bash
kubectl get pods -n sopra-hr
kubectl get svc -n sopra-hr
kubectl get deployments -n sopra-hr
```

### 10.2 Argo CD status

```bash
kubectl get applications -n argocd
# Should show: login-page   Synced   Healthy
```

### 10.3 Test the app externally

```bash
EXTERNAL_IP=$(kubectl get svc login-page-service -n sopra-hr -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "App URL: http://${EXTERNAL_IP}"
curl -s http://${EXTERNAL_IP} | head -20
```

### 10.4 GitHub Actions

Check: `https://github.com/MaramRezgui1/PFE_project/actions`

All stages should complete:
- ✅ Build
- ✅ Trivy Scan (check Security tab for results)
- ✅ Push to AR
- ✅ Cloud Run Deploy
- ✅ Update Manifest
- ✅ ArgoCD Sync
- ✅ Playwright E2E Tests (check job logs on GKE)
- ✅ ZAP Scan (check artifacts for HTML report)

---

## 11. Improvements & Recommendations

### Already implemented ✅

| Feature | Status |
|---------|--------|
| Workload Identity Federation (keyless CI/CD) | ✅ Done |
| Trivy image scanning (SAST) | ✅ Done |
| OWASP ZAP DAST scanning | ✅ Done |
| GitOps with Argo CD | ✅ Done |
| Multi-stage Docker build | ✅ Done |
| GKE Autopilot (managed nodes) | ✅ Done |
| Playwright E2E testing (local + GKE) | ✅ Done |
| Cloud Run deployment | ✅ Done |

### Remaining improvements

| # | Improvement | Priority | Description |
|---|------------|----------|-------------|
| 1 | **Remote Terraform state** | 🔴 High | Add GCS backend (currently local state) |
| 2 | **Network Policies** | 🟡 Medium | Add default-deny + allow rules in `sopra-hr` namespace |
| 3 | **HPA (Horizontal Pod Autoscaler)** | 🟡 Medium | Scale pods 2-8 based on CPU usage |
| 4 | **Ingress with HTTPS** | 🟡 Medium | Replace LoadBalancer with GCE Ingress + managed cert |
| 5 | **SonarCloud SAST** | 🟡 Medium | Add code quality analysis to pipeline |
| 6 | **Separate environments** | 🟢 Low | Use branches/namespaces for staging vs production |
| 7 | **Slack notifications** | 🟢 Low | Notify on pipeline failures |

---

## 12. Troubleshooting

### Terraform errors

| Error | Solution |
|-------|----------|
| `Error 403: The caller does not have permission` | Check `terraform-deployer-key.json` exists and has Owner role |
| `Quota exceeded` | Request quota increase in GCP Console for `europe-west9` |
| `Reference to undeclared resource` | Ensure resource names match (e.g., `google_container_cluster.primary` not `.main`) |
| `Output "cluster_name" not found` | Use hardcoded values (see Phase 3) |
| `WIF pool already exists (409)` | Pool was soft-deleted. Run: `gcloud iam workload-identity-pools undelete github-actions-pool --location=global --project=maram-pfe-495314` then `terraform import` |
| `Cannot import non-existent remote object` | Pool doesn't exist (even in deleted state). Just run `terraform apply` directly |

### GKE / Kubernetes errors

| Error | Solution |
|-------|----------|
| Pods stuck in `ImagePullBackOff` | Check IAM: compute SA needs `artifactregistry.reader` role |
| No nodes visible | Normal for Autopilot — nodes appear only when pods are scheduled |
| Argo CD app `OutOfSync` | Check `repoURL` and `targetRevision` in `argocd/application.yaml` |
| `could not parse resource []` | Env vars not set. Use literal values directly |

### GitHub Actions errors

| Error | Solution |
|-------|----------|
| `google-github-actions/auth failed` | Verify `WIF_PROVIDER` and `WIF_SERVICE_ACCOUNT` secrets are set correctly |
| `Permission 'iam.serviceAccounts.getAccessToken' denied` | WIF binding missing. Check `google_service_account_iam_member.github_actions_wif` in Terraform |
| `Permission denied on Artifact Registry` | Check `github-actions-sa` has `artifactregistry.writer` role |
| Trivy fails with CRITICAL CVEs | Fix the vulnerable packages in Dockerfile (update base images or pin versions) |
| ZAP scan fails | Check `.zap/rules.tsv` for false positive rules; ensure app is reachable via port-forward |

### Playwright E2E errors

| Error | Solution |
|-------|----------|
| `npx playwright test` fails locally | Ensure app is running on `http://localhost:8080` (run `npm run build && npx vite preview --port 8080`) |
| `Browser not found` | Run `npx playwright install --with-deps chromium` |
| K8s Job `ImagePullBackOff` | Ensure `playwright-tests` image was pushed to Artifact Registry |
| K8s Job timeout | Check pod logs: `kubectl logs job/playwright-e2e-tests -n sopra-hr`; verify service DNS is reachable |
| Tests pass locally but fail on GKE | Ensure `VITE_MOCK_USERS` env var was baked into the app image at build time |

---

## Quick Reference — Complete Command Sequence

```bash
# ═══════════════════════════════════════════════════════
# FULL RECREATION — Copy-paste friendly (all literal values)
# ═══════════════════════════════════════════════════════

# ── 1. GCP Setup ──
gcloud auth login
gcloud config set project maram-pfe-495314
gcloud services enable \
  serviceusage.googleapis.com \
  cloudresourcemanager.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  --project=maram-pfe-495314

# ── 2. Artifact Registry ──
gcloud artifacts repositories create sopra-repo \
  --repository-format=docker \
  --location=europe-west9 \
  --project=maram-pfe-495314 || true

# ── 3. Terraform ──
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Get GitHub Secrets values
echo "WIF_PROVIDER = $(terraform output -raw wif_provider)"
echo "WIF_SERVICE_ACCOUNT = $(terraform output -raw wif_service_account)"
cd ..

# ── 4. Connect to cluster ──
gcloud container clusters get-credentials maram-cluster-terraform \
  --region europe-west9 \
  --project maram-pfe-495314

# ── 5. Deploy app ──
kubectl apply -f terraform/k8s-deployment.yaml

# ── 6. Argo CD ──
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl rollout status deploy/argocd-server -n argocd --timeout=300s
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD password: ${ARGOCD_PASSWORD}"
kubectl apply -f argocd/application.yaml

# ── 7. Monitoring (optional) ──
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace observability
helm upgrade --install kube-prom prometheus-community/kube-prometheus-stack \
  -n observability --set grafana.adminPassword="DevOps2025!" --wait --timeout 10m

# ── 8. Add GitHub Secrets ──
# Go to: https://github.com/MaramRezgui1/PFE_project/settings/secrets/actions
# Add WIF_PROVIDER and WIF_SERVICE_ACCOUNT from terraform outputs above

# ── 9. Playwright E2E Tests (local validation) ──
npm install -D @playwright/test
npx playwright install --with-deps chromium
npm run build
npx vite preview --port 8080 &
npm run test:e2e

# ── 10. Trigger pipeline ──
git add .
git commit -m "feat: trigger CI/CD"
git push origin main
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     GCP Project: maram-pfe-495314                │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  VPC: maram-vpc (10.0.0.0/22)                             │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  GKE Autopilot: maram-cluster-terraform             │  │  │
│  │  │  Region: europe-west9                               │  │  │
│  │  │                                                     │  │  │
│  │  │  ┌───────────────┐  ┌─────────────┐  ┌──────────┐  │  │  │
│  │  │  │  sopra-hr ns  │  │  argocd ns  │  │observab. │  │  │  │
│  │  │  │               │  │             │  │namespace │  │  │  │
│  │  │  │  login-page   │  │  Argo CD    │  │Prometheus│  │  │  │
│  │  │  │  (Deployment) │  │  Server     │  │ Grafana  │  │  │  │
│  │  │  │  nginx:8080   │  │             │  │          │  │  │  │
│  │  │  │               │  └─────────────┘  └──────────┘  │  │  │
│  │  │  │  playwright   │                                  │  │  │
│  │  │  │  (K8s Job)    │                                  │  │  │
│  │  │  └───────┬───────┘                                  │  │  │
│  │  │          │                                          │  │  │
│  │  └──────────┼──────────────────────────────────────────┘  │  │
│  │             ▼                                             │  │
│  │  ┌──────────────────┐                                    │  │
│  │  │  LoadBalancer     │                                    │  │
│  │  │  :80 → :8080     │                                    │  │
│  │  └──────────────────┘                                    │  │
│  │                                                           │  │
│  │  ┌──────────────────┐    ┌─────────────────────────────┐ │  │
│  │  │ Artifact Registry │    │  WIF Pool: github-actions   │ │  │
│  │  │ sopra-repo        │    │  Provider: github-provider  │ │  │
│  │  │  - login-page     │    └─────────────────────────────┘ │  │
│  │  │  - playwright-tests│                                   │  │
│  │  └──────────────────┘                                    │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

         ▲                         ▲
         │ WIF (keyless OIDC)      │ GitOps (auto-sync)
         │                         │
┌────────┴─────────────────────────┐    ┌───────┴───────┐
│  GitHub Actions                   │    │   Argo CD     │
│                                   │    │  (in-cluster) │
│  1. Build image                   │    │               │
│  2. Trivy scan (CVE check)       │    │  Watches Git  │
│  3. Push to AR                    │───►│  Auto-syncs   │
│  4. Deploy to Cloud Run           │    │  k8s manifest │
│  5. Update k8s manifest           │    │               │
│  6. ArgoCD sync                   │    └───────────────┘
│  7. Build Playwright test image   │
│  8. Run Playwright E2E on GKE    │
│  9. OWASP ZAP DAST scan          │
└───────────────────────────────────┘
```

---

*Generated for the `login-page-replicator` DevSecOps PFE project — Maram Rezgui.*
















