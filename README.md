# Expensy — End-to-End DevOps Deployment

## Overview
Expensy is an expense tracker application with a Node.js/Express backend,
a Next.js frontend, a MongoDB database, and Redis for caching.

This repository demonstrates a full DevOps lifecycle:
local development → containerization → CI/CD → cloud deployment → monitoring → security.

**Live Application:** https://nata-expensy.azure.ironlabs.online

---

## Project Structure

```
devops-final-project-ih/
├── expensy_backend/          ← Node.js/Express/TypeScript backend
├── expensy_frontend/         ← Next.js frontend
├── infrastructure/           ← Kubernetes manifests + Terraform
│   ├── terraform/            ← IaC for AKS cluster on Azure
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   ├── mongo-deployment.yaml
│   ├── mongo-service.yaml
│   ├── redis-deployment.yaml
│   ├── redis-service.yaml
│   ├── configmap.yaml
│   ├── secrets.yaml
│   ├── ingress.yaml
│   ├── cluster-issuer.yaml
│   ├── network-policy.yaml
│   └── hpa.yaml
├── helm/expensy/             ← Helm chart for deployment
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── monitoring/               ← Prometheus + Grafana config
│   ├── monitoring-values.yaml
│   └── grafana-dashboard.json
├── docker-compose.yaml       ← Local development
└── .github/workflows/
    └── ci-cd.yaml            ← GitHub Actions pipeline
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Next.js |
| Backend | Node.js, Express, TypeScript |
| Database | MongoDB |
| Cache | Redis |
| Containerization | Docker |
| Orchestration | Kubernetes (AKS) |
| IaC | Terraform |
| Helm | Package manager for Kubernetes |
| CI/CD | GitHub Actions |
| Monitoring | Prometheus + Grafana + Azure Monitor |
| Registry | Azure Container Registry (ACR) |
| Ingress | Nginx Ingress Controller |
| TLS | cert-manager + Let's Encrypt |

---

## 1. Local Development Setup

### Prerequisites
- Node.js 20+
- Docker + Docker Compose
- Git

### Step 1 — Clone the repository
```bash
git clone https://github.com/natavann/devops-final-project-ih
cd devops-final-project-ih
```

### Step 2 — Create environment file

Create `expensy_backend/.env` — never commit this file:
```
PORT=YOUR_BACKEND_PORT
DATABASE_URI=YOUR_MONGODB_CONNECTION_STRING
REDIS_HOST=YOUR_REDIS_HOST
REDIS_PORT=YOUR_REDIS_PORT
REDIS_PASSWORD=YOUR_REDIS_PASSWORD
```

> The `.env` file is added to `.gitignore` and must never be committed to GitHub.
> Real values are stored only on your local machine and in GitHub Secrets.

### Step 3 — Start with Docker Compose (recommended)
```bash
docker-compose up --build
```

This starts all 4 services:
- Frontend  → http://localhost:3001
- Backend   → http://localhost:8706
- MongoDB   → localhost:27017
- Redis     → localhost:6379

### Step 4 — Run without Docker

```bash
# Start MongoDB and Redis containers
docker start mongo redis

# Terminal 1 — Backend
cd expensy_backend
npm install
npm run dev

# Terminal 2 — Frontend
cd expensy_frontend
npm install
npm run dev
```

### Problems fixed during local setup
- Missing `dev` script in `package.json` → added `ts-node-dev --respawn src/server.ts`
- Wrong `.env` format (`:` instead of `=`) → fixed to use `=`
- Missing `dotenv.config()` in `redis.ts` → added to load env variables
- `.env` was tracked by git → removed with `git rm --cached` and added to `.gitignore`

---

## 2. CI/CD Pipeline

### File: `.github/workflows/ci-cd.yaml`

The pipeline triggers on every push to `main` branch:

```
Push to main branch
        ↓
Job 1: build-and-test-backend
  → Checkout code
  → Setup Node.js 20
  → npm install
  → npm run build
        ↓
Job 2: build-and-test-frontend
  → Checkout code
  → Setup Node.js 20
  → npm install
  → npm run build
        ↓
Job 3: deploy-to-aks (main branch only)
  → Login to Azure
  → Login to ACR
  → Connect kubectl to AKS
  → helm upgrade --install (secrets injected from GitHub Secrets)
```

### GitHub Secrets required

All sensitive values are stored in GitHub Secrets — never in code.

| Secret | Description |
|--------|-------------|
| DATABASE_URI | MongoDB connection string |
| REDIS_PASSWORD | Redis password |
| NEXT_PUBLIC_API_URL | Backend API URL |
| MONGO_ROOT_USERNAME | MongoDB root username |
| MONGO_ROOT_PASSWORD | MongoDB root password |
| AZURE_CREDENTIALS | Azure service principal JSON |

### How to configure secrets
1. Go to GitHub repo → **Settings**
2. Click **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret from the table above

> Secrets are injected into the pipeline at runtime via `${{ secrets.SECRET_NAME }}`.
> They are never printed in logs or stored in any file.

---

## 3. Containerization

### Dockerfiles
- `expensy_backend/Dockerfile.backend`
- `expensy_frontend/Dockerfile.frontend`

### Multi-stage build
Both Dockerfiles use multi-stage builds:

```
Stage 1 (builder):
  - Installs all dependencies
  - Compiles TypeScript → JavaScript (backend)
  - Builds Next.js app (frontend)

Stage 2 (production):
  - Copies only compiled output
  - Installs production dependencies only
  - Result: smaller, more secure image
```

### Build and push to ACR
```bash
# Login to ACR
az acr login --name nataexpensyacr

# Build for AMD64 (AKS runs AMD64, Mac M1/M2 is ARM64)
docker buildx build --platform linux/amd64 \
  -t nataexpensyacr.azurecr.io/expensy-backend:latest \
  -f expensy_backend/Dockerfile.backend \
  expensy_backend/ --push

docker buildx build --platform linux/amd64 \
  -t nataexpensyacr.azurecr.io/expensy-frontend:latest \
  -f expensy_frontend/Dockerfile.frontend \
  expensy_frontend/ --push
```

---

## 4. Infrastructure — Terraform + AKS

### What Terraform creates
- **Resource Group:** `nata-expensy-rg`
- **AKS Cluster:** `nata-expensy-cluster` (2 nodes, availability zone 3, East US)
- **ACR:** `nataexpensyacr` (private container registry)
- **Standard Load Balancer**
- **AcrPull role assignment** (allows AKS to pull from ACR without credentials)

### Deploy infrastructure
```bash
cd infrastructure/terraform

# Initialize Terraform
terraform init

# Preview what will be created
terraform plan

# Create everything on Azure
terraform apply
```

### Connect kubectl to AKS
```bash
az aks get-credentials \
  --resource-group nata-expensy-rg \
  --name nata-expensy-cluster

# Verify
kubectl get nodes
```

---

## 5. Kubernetes Deployment

### Using Helm (recommended)

Secrets are passed at deploy time — never stored in files:

```bash
# Install
helm install expensy ./helm/expensy \
  --set secrets.databaseUri="YOUR_DATABASE_URI" \
  --set secrets.redisPassword="YOUR_REDIS_PASSWORD" \
  --set secrets.mongoRootUsername="YOUR_MONGO_USERNAME" \
  --set secrets.mongoRootPassword="YOUR_MONGO_PASSWORD"

# Upgrade
helm upgrade expensy ./helm/expensy \
  --set secrets.databaseUri="YOUR_DATABASE_URI" \
  --set secrets.redisPassword="YOUR_REDIS_PASSWORD" \
  --set secrets.mongoRootUsername="YOUR_MONGO_USERNAME" \
  --set secrets.mongoRootPassword="YOUR_MONGO_PASSWORD"
```

> In CI/CD pipeline, these values come from GitHub Secrets automatically:
> `--set secrets.redisPassword="${{ secrets.REDIS_PASSWORD }}"`

### Using raw Kubernetes manifests
```bash
# Edit infrastructure/secrets.yaml with your real values first
kubectl apply -f infrastructure/secrets.yaml
kubectl apply -f infrastructure/
```

### Install Nginx Ingress Controller
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

### Verify deployment
```bash
kubectl get pods
kubectl get services
kubectl get ingress
```

### Expected output
```
NAME                    READY   STATUS
backend-xxx             1/1     Running
frontend-xxx            1/1     Running
mongo-xxx               1/1     Running
redis-xxx               1/1     Running
```

---

## 6. Autoscaling (HPA)

Horizontal Pod Autoscaler automatically scales backend and frontend pods based on CPU and memory usage.

### Configuration
| Setting | Value |
|---------|-------|
| Min replicas | 1 |
| Max replicas | 5 |
| CPU threshold | 50% |
| Memory threshold | 70% |

### Check autoscaling status
```bash
kubectl get hpa
```

Expected output:
```
NAME           REFERENCE             TARGETS                        MINPODS   MAXPODS   REPLICAS
backend-hpa    Deployment/backend    cpu: 1%/50%, memory: 18%/70%   1         5         1
frontend-hpa   Deployment/frontend   cpu: 3%/50%, memory: 22%/70%   1         5         1
```

When CPU exceeds 50% or memory exceeds 70%, Kubernetes automatically adds pods up to 5.
When load decreases, pods are automatically removed down to minimum 1.

---

## 7. Monitoring & Logging

### Install Prometheus + Grafana
```bash
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/monitoring-values.yaml
```

### Access Grafana
```bash
# Get admin password
kubectl --namespace monitoring get secrets monitoring-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d ; echo

# Port forward
kubectl --namespace monitoring port-forward \
  svc/monitoring-grafana 3000:80
```

Open **http://localhost:3000**
- Username: `admin`
- Password: from command above

### View dashboards
- Go to **Dashboards** → **Browse**
- Search **"Kubernetes / Compute Resources / Cluster"**
- Shows CPU, Memory, Network per namespace
- Your app runs in `default` namespace

### Enable Azure Monitor
```bash
az aks enable-addons \
  --resource-group nata-expensy-rg \
  --name nata-expensy-cluster \
  --addons monitoring
```

### View logs in Azure Portal
1. Go to `nata-expensy-cluster` in Azure Portal
2. Click **Monitor** → **Containers** tab
3. Filter by container name

### View logs via kubectl
```bash
# Backend logs
kubectl logs -l app=backend --tail=100

# Frontend logs
kubectl logs -l app=frontend --tail=100

# Live stream
kubectl logs -l app=backend -f
```

---

## 8. Security

### TLS/HTTPS

#### Install cert-manager
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

#### Apply ClusterIssuer and Ingress
```bash
kubectl apply -f infrastructure/cluster-issuer.yaml
kubectl apply -f infrastructure/ingress.yaml
```

#### Verify certificate
```bash
kubectl get certificate
# NAME          READY
# expensy-tls   True
```

### Network Policies
```bash
kubectl apply -f infrastructure/network-policy.yaml
```

Traffic restrictions:
- `backend` → accessible only from `frontend`
- `mongo` → accessible only from `backend`
- `redis` → accessible only from `backend`
- `frontend` → accessible from internet via Ingress only

### Secret Management

I follow a 3-layer approach — real passwords are NEVER in code:

```
Layer 1 — Code (GitHub):
  Placeholder values only (YOUR_PASSWORD, REPLACE_WITH_*)
  Safe to commit ✅

Layer 2 — GitHub Secrets:
  Real values stored encrypted in GitHub
  Used by CI/CD pipeline at deploy time
  Never visible in logs or files ✅

Layer 3 — Kubernetes Secrets:
  Real values stored encrypted in K8s etcd
  Accessed by pods via secretKeyRef only ✅
```

### IAM
- AKS uses **SystemAssigned managed identity** (no root credentials)
- **AcrPull role** assigned via Terraform (AKS pulls images from ACR without credentials)

---

## 9. Architecture

```
Developer pushes code
        ↓
GitHub Actions (CI/CD)
  → builds backend + frontend
  → deploys via Helm to AKS
  → secrets injected from GitHub Secrets vault
        ↓
Azure AKS Cluster
        ↓
Internet → Azure Load Balancer
                ↓
         Nginx Ingress Controller
         (HTTPS via cert-manager + Let's Encrypt)
                ↓
    ┌──────────────────────────────┐
    │                              │
Frontend Pod                Backend Pod
(Next.js)                (Node/Express)
                            ↓       ↓
                       MongoDB    Redis
                         Pod       Pod
    └──────────────────────────────┘
            ↑
  ACR (nataexpensyacr.azurecr.io)
  Private registry - AKS pulls via AcrPull role

Monitoring:
  Prometheus → scrapes metrics from pods
  Grafana    → visualizes metrics
  Azure Monitor → container logs

Autoscaling:
  HPA → scales backend/frontend 1-5 pods
        based on CPU (50%) and memory (70%)
```

---

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Certificate not issuing
```bash
kubectl describe certificate expensy-tls
kubectl get challenges
```

### Helm deployment failing
```bash
helm status expensy
helm history expensy
```

### Check all resources
```bash
kubectl get all
kubectl get all -n monitoring
kubectl get all -n ingress-nginx
kubectl get all -n cert-manager
```
