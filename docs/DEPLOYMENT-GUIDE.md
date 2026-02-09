# Knative Airgapped Deployment Guide

This guide walks you through deploying Knative Operator and Knative Serving in an airgapped environment using a private Harbor registry.

## Overview

In an airgapped environment, you cannot pull images from the public internet. This guide covers:

1. **Connected Environment**: Setting up Harbor and mirroring all required images
2. **Airgapped Environment**: Deploying Knative using only the private registry
3. **Verification**: Testing the deployment

## Prerequisites

### Connected Environment (for image preparation)
- Docker or container runtime
- kubectl
- Internet access
- Enough disk space for container images (~2-3 GB)

### Airgapped Environment
- Kubernetes cluster (k3s, kind, or any distribution)
- kubectl
- Network access to private Harbor registry
- Registry credentials

## Part 1: Setting Up Harbor Registry (Connected Environment)

### Option A: Harbor on Kubernetes (Recommended)

Harbor will run on your existing Rancher Desktop cluster.

```bash
# Add Harbor Helm repo
helm repo add harbor https://helm.goharbor.io
helm repo update

# Create namespace
kubectl create namespace harbor

# Install Harbor
helm install harbor harbor/harbor \
  --namespace harbor \
  --set expose.type=nodePort \
  --set expose.tls.enabled=false \
  --set externalURL=http://harbor.local \
  --set persistence.enabled=true \
  --set harborAdminPassword=Harbor12345

# Wait for Harbor to be ready
kubectl wait --for=condition=ready pod -l app=harbor -n harbor --timeout=300s
```

### Option B: Harbor with Docker Compose (Alternative)

If you prefer Harbor outside Kubernetes:

```bash
# Download Harbor installer
curl -LO https://github.com/goharbor/harbor/releases/download/v2.11.0/harbor-offline-installer-v2.11.0.tgz
tar xvf harbor-offline-installer-v2.11.0.tgz
cd harbor

# Configure Harbor
cp harbor.yml.tmpl harbor.yml
# Edit harbor.yml:
#   - Set hostname to your IP or localhost
#   - Set admin password
#   - Disable HTTPS if testing locally

# Install and start
sudo ./install.sh
```

### Access Harbor

For Kubernetes deployment:
```bash
# Get NodePort
kubectl get svc harbor-portal -n harbor

# Access Harbor UI
# http://localhost:<nodeport>
# Default credentials: admin / Harbor12345
```

### Create Project in Harbor

1. Log in to Harbor UI
2. Click "New Project"
3. Project Name: **knative**
4. Access Level: Private
5. Click OK

## Part 2: Identify and Mirror Knative Images

### List of Required Images

**Knative Operator:**
- gcr.io/knative-releases/knative.dev/operator/cmd/operator
- gcr.io/knative-releases/knative.dev/operator/cmd/webhook

**Knative Serving (v1.15.0):**
- gcr.io/knative-releases/knative.dev/serving/cmd/activator
- gcr.io/knative-releases/knative.dev/serving/cmd/autoscaler
- gcr.io/knative-releases/knative.dev/serving/cmd/autoscaler-hpa
- gcr.io/knative-releases/knative.dev/serving/cmd/controller
- gcr.io/knative-releases/knative.dev/serving/cmd/webhook
- gcr.io/knative-releases/knative.dev/net-kourier/cmd/kourier
- gcr.io/knative-releases/knative.dev/serving/cmd/queue
- gcr.io/knative-releases/knative.dev/serving/cmd/default-domain

### Mirror Images Script

Use the provided `mirror-images.sh` script:

```bash
./mirror-images.sh <harbor-url> <project-name>

# Example:
./mirror-images.sh harbor.local:30002 knative
```

The script will:
1. Pull all images from public registries
2. Re-tag them for your private registry
3. Push to Harbor
4. Generate an image mapping file

## Part 3: Deploy in Airgapped Environment

### Prerequisites in Airgapped Environment

1. **Network access to Harbor registry**
2. **Registry credentials configured**

```bash
# Create docker-registry secret
kubectl create secret docker-registry harbor-creds \
  --docker-server=<harbor-url> \
  --docker-username=admin \
  --docker-password=<password> \
  --docker-email=admin@example.com
```

3. **Modified Knative manifests** (use provided `deploy-airgap.sh`)

### Deploy Knative Operator

```bash
# Apply modified operator manifest
kubectl apply -f operator-airgap.yaml
```

### Deploy Knative Serving

```bash
# Apply Knative Serving with private registry
kubectl apply -f knative-serving-airgap.yaml
```

### Verify Deployment

```bash
# Check operator
kubectl get pods -n knative-operator

# Check serving
kubectl get pods -n knative-serving

# Check Knative Serving status
kubectl get knativeserving -n knative-serving
```

## Part 4: Testing

### Deploy Test Service

```bash
cat <<EOF | kubectl apply -f -
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: hello-airgap
spec:
  template:
    metadata:
      annotations:
        # Use private registry for app images too
    spec:
      imagePullSecrets:
      - name: harbor-creds
      containers:
      - image: <harbor-url>/knative/helloworld-go:latest
        env:
        - name: TARGET
          value: "Airgapped World"
EOF
```

### Verify Service

```bash
# Check service status
kubectl get ksvc hello-airgap

# Port-forward and test
kubectl port-forward -n knative-serving svc/kourier 8080:80

# In another terminal
curl -H "Host: hello-airgap.default.127.0.0.1.sslip.io" http://localhost:8080
```

## Troubleshooting

### Images Not Pulling

**Check image pull secrets:**
```bash
kubectl get secret harbor-creds -o yaml
```

**Verify registry connectivity from cluster:**
```bash
kubectl run test --image=<harbor-url>/knative/activator:latest --command -- sleep 3600
kubectl logs test
```

### Operator Not Starting

**Check operator logs:**
```bash
kubectl logs -n knative-operator deployment/knative-operator
```

**Common issues:**
- Wrong registry URL in manifests
- Missing authentication
- Network connectivity to registry

### Serving Components Failing

**Check events:**
```bash
kubectl get events -n knative-serving --sort-by='.lastTimestamp'
```

**Check specific pod:**
```bash
kubectl describe pod <pod-name> -n knative-serving
```

## Image List Reference

Full list of images with versions is maintained in `images.txt`.

To update the list for a different Knative version:

```bash
# Download operator manifest
curl -sL https://github.com/knative/operator/releases/download/knative-v1.15.0/operator.yaml | \
  grep 'image:' | awk '{print $2}' | sort -u > operator-images.txt

# For serving images, they're pulled by operator but listed in the KnativeServing spec
```

## Security Considerations

1. **TLS/HTTPS**: Enable TLS for Harbor in production
2. **Image Scanning**: Use Harbor's built-in Trivy scanning
3. **Access Control**: Use RBAC in Harbor for different projects/teams
4. **Image Signing**: Consider signing images with Cosign
5. **Network Policies**: Restrict pod-to-registry traffic

## Automation

For regular updates or multiple deployments:

1. **CI/CD Pipeline**: Automate image mirroring
2. **GitOps**: Use ArgoCD/Flux with private registry
3. **Image Synchronization**: Set up periodic sync jobs
4. **Version Pinning**: Always pin specific versions in production

## Appendix: Manual Image Mirroring

If the script doesn't work, manually mirror images:

```bash
# Pull from public
docker pull gcr.io/knative-releases/knative.dev/operator/cmd/operator:v1.15.0

# Tag for private registry
docker tag gcr.io/knative-releases/knative.dev/operator/cmd/operator:v1.15.0 \
  harbor.local:30002/knative/operator:v1.15.0

# Push to private registry
docker push harbor.local:30002/knative/operator:v1.15.0
```

## Next Steps

1. Test this guide in a connected environment first
2. Document any customizations for your specific setup
3. Create runbooks for your operations team
4. Set up monitoring and alerting for registry and Knative components
