#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# setup-cluster.sh — Post-Terraform GKE Cluster Configuration Script
# ═══════════════════════════════════════════════════════════════════════════════
#
# This script configures the GKE cluster after Terraform has provisioned
# the infrastructure. It installs and configures:
#   1. Connect to GKE cluster
#   2. Deploy the application (namespace, deployment, service)
#   3. Install Argo CD (GitOps)
#   4. Register the Argo CD Application
#   5. Install Prometheus & Grafana (monitoring)
#   6. Validate all components
#
# Usage:
#   chmod +x scripts/setup-cluster.sh
#   ./scripts/setup-cluster.sh
#
# Prerequisites:
#   - Terraform apply completed successfully
#   - gcloud CLI authenticated
#   - kubectl, helm installed
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
PROJECT_ID="maram-pfe-495314"
REGION="europe-west9"
CLUSTER_NAME="maram-cluster-terraform"
APP_NAMESPACE="sopra-hr"
ARGOCD_NAMESPACE="argocd"
MONITORING_NAMESPACE="observability"
GRAFANA_PASSWORD="DevOps2025!"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ─── Colors & Formatting ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ─── Helper Functions ─────────────────────────────────────────────────────────
log_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${PURPLE}  STEP $1: $2${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

log_info() {
    echo -e "${CYAN}  ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}  ✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}  ⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}  ❌ $1${NC}"
}

log_action() {
    echo -e "${BOLD}  ▶ $1${NC}"
}

separator() {
    echo -e "${BLUE}  ──────────────────────────────────────────────────────────────────────────${NC}"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

wait_for_rollout() {
    local resource=$1
    local namespace=$2
    local timeout=${3:-300s}
    log_info "Waiting for ${resource} to be ready (timeout: ${timeout})..."
    if kubectl rollout status "${resource}" -n "${namespace}" --timeout="${timeout}" 2>/dev/null; then
        log_success "${resource} is ready!"
    else
        log_error "${resource} failed to become ready within ${timeout}"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN SCRIPT
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${PURPLE}║           🚀 GKE CLUSTER SETUP — Post-Terraform Configuration             ║${NC}"
echo -e "${BOLD}${PURPLE}║                                                                            ║${NC}"
echo -e "${BOLD}${PURPLE}║  Project:  ${PROJECT_ID}                                   ║${NC}"
echo -e "${BOLD}${PURPLE}║  Cluster:  ${CLUSTER_NAME}                         ║${NC}"
echo -e "${BOLD}${PURPLE}║  Region:   ${REGION}                                          ║${NC}"
echo -e "${BOLD}${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ─── Prerequisites Check ─────────────────────────────────────────────────────
log_step "0" "Checking prerequisites"

log_action "Verifying required tools..."
check_command gcloud
check_command kubectl
check_command helm

log_success "gcloud  — $(gcloud version 2>/dev/null | head -1)"
log_success "kubectl — $(kubectl version --client --short 2>/dev/null || kubectl version --client -o yaml | grep gitVersion | awk '{print $2}')"
log_success "helm    — $(helm version --short 2>/dev/null)"
echo ""

log_action "Verifying gcloud authentication..."
ACCOUNT=$(gcloud config get-value account 2>/dev/null)
if [ -z "${ACCOUNT}" ]; then
    log_error "Not authenticated with gcloud. Run: gcloud auth login"
    exit 1
fi
log_success "Authenticated as: ${ACCOUNT}"

log_action "Verifying project is set..."
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ "${CURRENT_PROJECT}" != "${PROJECT_ID}" ]; then
    log_warning "Current project is '${CURRENT_PROJECT}', switching to '${PROJECT_ID}'..."
    gcloud config set project "${PROJECT_ID}" 2>/dev/null
fi
log_success "Project: ${PROJECT_ID}"


# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: Connect to GKE Cluster
# ═══════════════════════════════════════════════════════════════════════════════
log_step "1" "Connecting to GKE Cluster"

log_action "Fetching cluster credentials..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --region "${REGION}" \
    --project "${PROJECT_ID}"

log_success "Connected to cluster: ${CLUSTER_NAME}"

separator
log_action "Verifying cluster connection..."
echo ""
kubectl cluster-info 2>/dev/null | head -3
echo ""

log_action "Checking cluster nodes (Autopilot nodes appear when workloads are scheduled)..."
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
if [ "${NODE_COUNT}" -gt 0 ]; then
    kubectl get nodes -o wide
    log_success "Cluster has ${NODE_COUNT} node(s) ready"
else
    log_info "No nodes visible yet — this is normal for GKE Autopilot (nodes appear when pods are scheduled)"
fi


# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: Deploy Application
# ═══════════════════════════════════════════════════════════════════════════════
log_step "2" "Deploying Application to namespace '${APP_NAMESPACE}'"

log_action "Applying Kubernetes manifest: terraform/k8s-deployment.yaml"
log_info "This creates: Namespace(sopra-hr) + Deployment(login-page) + Service(LoadBalancer)"
echo ""

kubectl apply -f "${PROJECT_ROOT}/terraform/k8s-deployment.yaml"

echo ""
log_success "Manifest applied successfully"

separator
log_action "Waiting for deployment to be ready..."
# Give Autopilot time to provision nodes
sleep 5
wait_for_rollout "deployment/login-page" "${APP_NAMESPACE}" "300s"

separator
log_action "Checking pods status..."
echo ""
kubectl get pods -n "${APP_NAMESPACE}" -o wide
echo ""

separator
log_action "Waiting for LoadBalancer external IP (this can take 1-3 minutes)..."
ATTEMPTS=0
MAX_ATTEMPTS=36  # 3 minutes (36 x 5s)
EXTERNAL_IP=""

while [ ${ATTEMPTS} -lt ${MAX_ATTEMPTS} ]; do
    EXTERNAL_IP=$(kubectl get svc login-page-service -n "${APP_NAMESPACE}" \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "${EXTERNAL_IP}" ] && [ "${EXTERNAL_IP}" != "null" ]; then
        break
    fi
    ATTEMPTS=$((ATTEMPTS + 1))
    echo -ne "\r  ⏳ Waiting for external IP... (${ATTEMPTS}/${MAX_ATTEMPTS})"
    sleep 5
done
echo ""

if [ -n "${EXTERNAL_IP}" ] && [ "${EXTERNAL_IP}" != "null" ]; then
    log_success "Application is accessible at: http://${EXTERNAL_IP}"
    separator
    log_action "Testing application connectivity..."
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${EXTERNAL_IP}" --connect-timeout 10 || echo "000")
    if [ "${HTTP_STATUS}" == "200" ]; then
        log_success "Application responds with HTTP 200 ✓"
    else
        log_warning "Application returned HTTP ${HTTP_STATUS} (may still be starting)"
    fi
else
    log_warning "External IP not yet assigned. Check with: kubectl get svc -n ${APP_NAMESPACE}"
fi


# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Install Argo CD
# ═══════════════════════════════════════════════════════════════════════════════
log_step "3" "Installing Argo CD (GitOps)"

log_action "Creating namespace '${ARGOCD_NAMESPACE}'..."
kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
log_success "Namespace '${ARGOCD_NAMESPACE}' ready"

separator
log_action "Installing Argo CD from official manifests..."
log_info "Source: https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
echo ""

kubectl apply -n "${ARGOCD_NAMESPACE}" \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ""
log_success "Argo CD manifests applied"

separator
log_action "Waiting for Argo CD server to be ready..."
wait_for_rollout "deployment/argocd-server" "${ARGOCD_NAMESPACE}" "300s"
wait_for_rollout "deployment/argocd-repo-server" "${ARGOCD_NAMESPACE}" "300s"
wait_for_rollout "deployment/argocd-applicationset-controller" "${ARGOCD_NAMESPACE}" "300s"

separator
log_action "Retrieving Argo CD admin password..."
# Wait for the secret to be available
sleep 5
ARGOCD_PASSWORD=""
ATTEMPTS=0
while [ ${ATTEMPTS} -lt 12 ]; do
    ARGOCD_PASSWORD=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
    if [ -n "${ARGOCD_PASSWORD}" ]; then
        break
    fi
    ATTEMPTS=$((ATTEMPTS + 1))
    sleep 5
done

if [ -n "${ARGOCD_PASSWORD}" ]; then
    echo ""
    echo -e "  ${BOLD}┌────────────────────────────────────────────┐${NC}"
    echo -e "  ${BOLD}│  🔐 Argo CD Credentials                    │${NC}"
    echo -e "  ${BOLD}│                                            │${NC}"
    echo -e "  ${BOLD}│  URL:      https://localhost:8081           │${NC}"
    echo -e "  ${BOLD}│  Username: admin                           │${NC}"
    echo -e "  ${BOLD}│  Password: ${ARGOCD_PASSWORD}                       │${NC}"
    echo -e "  ${BOLD}│                                            │${NC}"
    echo -e "  ${BOLD}│  Access:                                   │${NC}"
    echo -e "  ${BOLD}│  kubectl port-forward svc/argocd-server    │${NC}"
    echo -e "  ${BOLD}│    -n argocd 8081:443                      │${NC}"
    echo -e "  ${BOLD}└────────────────────────────────────────────┘${NC}"
    echo ""
else
    log_warning "Could not retrieve ArgoCD password. Get it manually with:"
    log_info "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
fi

separator
log_action "Checking Argo CD pods status..."
echo ""
kubectl get pods -n "${ARGOCD_NAMESPACE}" --sort-by=.metadata.name
echo ""
log_success "Argo CD installation complete"


# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: Register Argo CD Application (GitOps)
# ═══════════════════════════════════════════════════════════════════════════════
log_step "4" "Registering Argo CD Application (GitOps sync)"

log_action "Applying ArgoCD Application manifest: argocd/application.yaml"
log_info "Argo CD will watch: https://github.com/MaramRezgui1/PFE_project (branch: main)"
log_info "Path: terraform/k8s-deployment.yaml → namespace: sopra-hr"
log_info "Auto-sync: enabled (prune + self-heal)"
echo ""

kubectl apply -f "${PROJECT_ROOT}/argocd/application.yaml"

echo ""
log_success "Argo CD Application 'login-page' registered"

separator
log_action "Waiting for Argo CD to sync (checking application status)..."
sleep 10

SYNC_STATUS=""
HEALTH_STATUS=""
ATTEMPTS=0
while [ ${ATTEMPTS} -lt 24 ]; do  # 2 minutes max
    SYNC_STATUS=$(kubectl get application login-page -n "${ARGOCD_NAMESPACE}" \
        -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    HEALTH_STATUS=$(kubectl get application login-page -n "${ARGOCD_NAMESPACE}" \
        -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")

    if [ "${SYNC_STATUS}" == "Synced" ] && [ "${HEALTH_STATUS}" == "Healthy" ]; then
        break
    fi
    ATTEMPTS=$((ATTEMPTS + 1))
    echo -ne "\r  ⏳ Sync: ${SYNC_STATUS} | Health: ${HEALTH_STATUS} (waiting...${ATTEMPTS}/24)"
    sleep 5
done
echo ""

if [ "${SYNC_STATUS}" == "Synced" ] && [ "${HEALTH_STATUS}" == "Healthy" ]; then
    log_success "Argo CD Application Status: Synced ✓ | Healthy ✓"
else
    log_warning "Argo CD Application Status: Sync=${SYNC_STATUS} | Health=${HEALTH_STATUS}"
    log_info "It may take a moment. Check: kubectl get applications -n argocd"
fi

separator
log_action "Application details:"
echo ""
kubectl get applications -n "${ARGOCD_NAMESPACE}" -o wide 2>/dev/null || true
echo ""


# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: Install Prometheus & Grafana (Monitoring Stack)
# ═══════════════════════════════════════════════════════════════════════════════
log_step "5" "Installing Prometheus & Grafana (kube-prometheus-stack)"

log_action "Adding Helm repository: prometheus-community..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
log_success "Helm repositories updated"

separator
log_action "Creating namespace '${MONITORING_NAMESPACE}'..."
kubectl create namespace "${MONITORING_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
log_success "Namespace '${MONITORING_NAMESPACE}' ready"

separator
log_action "Installing kube-prometheus-stack via Helm..."
log_info "This includes: Prometheus, Grafana, AlertManager, node-exporter, kube-state-metrics"
log_info "Grafana admin password: ${GRAFANA_PASSWORD}"
log_warning "This may take 5-10 minutes on GKE Autopilot (nodes need provisioning)..."
echo ""

helm upgrade --install kube-prom prometheus-community/kube-prometheus-stack \
    --namespace "${MONITORING_NAMESPACE}" \
    --set grafana.adminPassword="${GRAFANA_PASSWORD}" \
    --set grafana.service.type=ClusterIP \
    --set prometheus.prometheusSpec.retention=7d \
    --set prometheus.prometheusSpec.resources.requests.memory=512Mi \
    --set prometheus.prometheusSpec.resources.requests.cpu=250m \
    --wait \
    --timeout 10m

echo ""
log_success "kube-prometheus-stack installed successfully"

separator
log_action "Checking monitoring pods..."
echo ""
kubectl get pods -n "${MONITORING_NAMESPACE}" --sort-by=.metadata.name
echo ""

separator
echo ""
echo -e "  ${BOLD}┌────────────────────────────────────────────┐${NC}"
echo -e "  ${BOLD}│  📊 Grafana Credentials                    │${NC}"
echo -e "  ${BOLD}│                                            │${NC}"
echo -e "  ${BOLD}│  URL:      http://localhost:3000            │${NC}"
echo -e "  ${BOLD}│  Username: admin                           │${NC}"
echo -e "  ${BOLD}│  Password: ${GRAFANA_PASSWORD}                       │${NC}"
echo -e "  ${BOLD}│                                            │${NC}"
echo -e "  ${BOLD}│  Access:                                   │${NC}"
echo -e "  ${BOLD}│  kubectl port-forward svc/kube-prom-grafana│${NC}"
echo -e "  ${BOLD}│    -n observability 3000:80                 │${NC}"
echo -e "  ${BOLD}└────────────────────────────────────────────┘${NC}"
echo ""

log_success "Monitoring stack installation complete"


# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: Final Validation
# ═══════════════════════════════════════════════════════════════════════════════
log_step "6" "Final Validation — All Components"

echo ""
echo -e "  ${BOLD}📋 Component Status Summary${NC}"
echo ""

# --- Application ---
separator
log_action "Application (namespace: ${APP_NAMESPACE})"
echo ""
kubectl get deployments -n "${APP_NAMESPACE}" 2>/dev/null
echo ""
kubectl get svc -n "${APP_NAMESPACE}" 2>/dev/null
echo ""

APP_PODS_READY=$(kubectl get deployment login-page -n "${APP_NAMESPACE}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "${APP_PODS_READY}" -gt 0 ] 2>/dev/null; then
    log_success "Application: ${APP_PODS_READY} pod(s) ready"
else
    log_warning "Application: pods not yet ready"
fi

# --- Argo CD ---
separator
log_action "Argo CD (namespace: ${ARGOCD_NAMESPACE})"
echo ""
kubectl get deployments -n "${ARGOCD_NAMESPACE}" 2>/dev/null | head -6
echo ""

ARGOCD_READY=$(kubectl get deployment argocd-server -n "${ARGOCD_NAMESPACE}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "${ARGOCD_READY}" -gt 0 ] 2>/dev/null; then
    log_success "Argo CD: Server running (${ARGOCD_READY} replica(s))"
else
    log_warning "Argo CD: Server not yet ready"
fi

# --- Monitoring ---
separator
log_action "Monitoring (namespace: ${MONITORING_NAMESPACE})"
echo ""
kubectl get deployments -n "${MONITORING_NAMESPACE}" 2>/dev/null
echo ""

GRAFANA_READY=$(kubectl get deployment kube-prom-grafana -n "${MONITORING_NAMESPACE}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
PROMETHEUS_READY=$(kubectl get statefulset -n "${MONITORING_NAMESPACE}" \
    -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null || echo "0")
if [ "${GRAFANA_READY}" -gt 0 ] 2>/dev/null; then
    log_success "Grafana: running (${GRAFANA_READY} replica(s))"
else
    log_warning "Grafana: not yet ready"
fi
if [ "${PROMETHEUS_READY}" -gt 0 ] 2>/dev/null; then
    log_success "Prometheus: running (${PROMETHEUS_READY} replica(s))"
else
    log_warning "Prometheus: not yet ready"
fi

# --- GitOps ---
separator
log_action "GitOps — Argo CD Applications"
echo ""
kubectl get applications -n "${ARGOCD_NAMESPACE}" 2>/dev/null
echo ""


# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                    🎉 CLUSTER SETUP COMPLETE!                               ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}📌 Quick Access Commands:${NC}"
echo ""
echo -e "  ${CYAN}# Application${NC}"
if [ -n "${EXTERNAL_IP}" ] && [ "${EXTERNAL_IP}" != "null" ]; then
    echo -e "  curl http://${EXTERNAL_IP}"
else
    echo -e "  kubectl get svc login-page-service -n sopra-hr   # Get external IP"
fi
echo ""
echo -e "  ${CYAN}# Argo CD Dashboard${NC}"
echo -e "  kubectl port-forward svc/argocd-server -n argocd 8081:443 &"
echo -e "  # Open: https://localhost:8081 (admin / ${ARGOCD_PASSWORD:-<see-above>})"
echo ""
echo -e "  ${CYAN}# Grafana Dashboard${NC}"
echo -e "  kubectl port-forward svc/kube-prom-grafana -n observability 3000:80 &"
echo -e "  # Open: http://localhost:3000 (admin / ${GRAFANA_PASSWORD})"
echo ""
echo -e "  ${CYAN}# Prometheus${NC}"
echo -e "  kubectl port-forward svc/kube-prom-kube-prometheus-prometheus -n observability 9090:9090 &"
echo -e "  # Open: http://localhost:9090"
echo ""
echo -e "  ${CYAN}# Check all resources${NC}"
echo -e "  kubectl get all -n sopra-hr"
echo -e "  kubectl get all -n argocd"
echo -e "  kubectl get all -n observability"
echo ""
separator
echo ""
echo -e "  ${BOLD}🔄 Next Steps:${NC}"
echo -e "  1. Set GitHub secrets (WIF_PROVIDER, WIF_SERVICE_ACCOUNT) from terraform outputs"
echo -e "  2. Push code to main branch to trigger CI/CD pipeline"
echo -e "  3. Monitor pipeline at: https://github.com/MaramRezgui1/PFE_project/actions"
echo ""
echo -e "  ${BOLD}📖 Full guide: FULL-PROJECT-RECREATION-GUIDE.md${NC}"
echo ""

