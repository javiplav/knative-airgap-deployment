# Docker Registry Browser Guide

## Registry Information

**Type**: Docker Registry v2 (Official open-source registry)
**URL**: `localhost:30500`
**Deployment**: Kubernetes (registry namespace)
**Storage**: 10Gi PersistentVolumeClaim

## Browsing Options

### Option 1: Command-Line Script (Included)

Use the provided `browse-registry.sh` script:

```bash
# List all repositories
./browse-registry.sh list

# Show all images with details
./browse-registry.sh all

# Show specific image details
./browse-registry.sh show knative-activator
```

### Option 2: Direct API Calls

Docker Registry v2 provides a REST API:

```bash
# List all repositories
curl http://localhost:30500/v2/_catalog | jq .

# List tags for a specific image
curl http://localhost:30500/v2/knative-activator/tags/list | jq .

# Get image manifest
curl http://localhost:30500/v2/knative-activator/manifests/v1.15.0 | jq .

# Check registry version
curl http://localhost:30500/v2/
```

### Option 3: Add a Web UI

Docker Registry v2 doesn't include a web UI, but you can add one:

#### A. Docker Registry UI (Recommended - Simple)

Deploy Joxit's Docker Registry UI:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry-ui
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry-ui
  template:
    metadata:
      labels:
        app: registry-ui
    spec:
      containers:
      - name: registry-ui
        image: joxit/docker-registry-ui:latest
        ports:
        - containerPort: 80
        env:
        - name: REGISTRY_TITLE
          value: "Knative Airgap Registry"
        - name: REGISTRY_URL
          value: "http://registry.registry.svc.cluster.local:5000"
        - name: DELETE_IMAGES
          value: "true"
        - name: SHOW_CONTENT_DIGEST
          value: "true"
---
apiVersion: v1
kind: Service
metadata:
  name: registry-ui
  namespace: registry
spec:
  type: NodePort
  selector:
    app: registry-ui
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30600
EOF

# Access at: http://localhost:30600
```

#### B. Harbor (Full-Featured)

For production, consider Harbor (we tried this but had macOS compatibility issues):

```bash
# Harbor provides:
# - Web UI
# - Role-based access control
# - Image scanning (Trivy)
# - Replication
# - Webhooks
# - API

# Best for: Production environments on Linux
```

#### C. Portus

Another option with web UI and user management:

```bash
# Portus provides:
# - Web UI
# - User/team management
# - Security scanning
# - Activity tracking
```

### Option 4: Docker CLI

You can also use Docker CLI to interact:

```bash
# Search (requires registry to support search - v2 doesn't by default)
# But you can pull and inspect:

# Pull an image
docker pull localhost:30500/knative-activator:v1.15.0

# Inspect
docker inspect localhost:30500/knative-activator:v1.15.0

# List local images from registry
docker images | grep localhost:30500
```

## Quick Reference

### Common API Endpoints

| Endpoint | Purpose | Example |
|----------|---------|---------|
| `GET /v2/` | Check registry is alive | `curl http://localhost:30500/v2/` |
| `GET /v2/_catalog` | List all repositories | `curl http://localhost:30500/v2/_catalog` |
| `GET /v2/<name>/tags/list` | List tags for image | `curl http://localhost:30500/v2/knative-activator/tags/list` |
| `GET /v2/<name>/manifests/<tag>` | Get image manifest | `curl http://localhost:30500/v2/knative-activator/manifests/v1.15.0` |
| `DELETE /v2/<name>/manifests/<digest>` | Delete image (if enabled) | Advanced usage |

### Registry Configuration

Check current registry configuration:

```bash
kubectl get configmap -n registry
kubectl describe deployment registry -n registry
```

### Storage Location

The registry stores images in a PersistentVolume:

```bash
# Check PVC
kubectl get pvc -n registry

# Check storage usage
kubectl exec -n registry deployment/registry -- du -sh /var/lib/registry
```

## Installing Web UI (Detailed)

### Install Docker Registry UI

1. **Deploy the UI:**

```bash
# Save this as install-registry-ui.sh
cat > install-registry-ui.sh <<'EOFI'
#!/bin/bash
echo "Installing Docker Registry UI..."

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry-ui
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry-ui
  template:
    metadata:
      labels:
        app: registry-ui
    spec:
      containers:
      - name: registry-ui
        image: joxit/docker-registry-ui:latest
        ports:
        - containerPort: 80
        env:
        - name: REGISTRY_TITLE
          value: "Knative Airgap Registry"
        - name: REGISTRY_URL
          value: "http://registry.registry.svc.cluster.local:5000"
        - name: DELETE_IMAGES
          value: "true"
        - name: SHOW_CONTENT_DIGEST
          value: "true"
        - name: NGINX_PROXY_PASS_URL
          value: "http://registry.registry.svc.cluster.local:5000"
---
apiVersion: v1
kind: Service
metadata:
  name: registry-ui
  namespace: registry
spec:
  type: NodePort
  selector:
    app: registry-ui
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30600
EOF

echo ""
echo "Waiting for UI to be ready..."
kubectl wait --for=condition=ready pod -l app=registry-ui -n registry --timeout=120s

echo ""
echo "✅ Docker Registry UI installed!"
echo ""
echo "Access at: http://localhost:30600"
echo ""
EOFI

chmod +x install-registry-ui.sh
./install-registry-ui.sh
```

2. **Access the UI:**

Open your browser to: **http://localhost:30600**

You'll see:
- All repositories listed
- Tags for each image
- Image details
- Option to delete images (if configured)

## Useful Commands

### Browse via curl

```bash
# Pretty print all repositories
curl -s http://localhost:30500/v2/_catalog | jq -r '.repositories[]' | sort

# Get all tags for all images
for repo in $(curl -s http://localhost:30500/v2/_catalog | jq -r '.repositories[]'); do
  echo "=== $repo ==="
  curl -s http://localhost:30500/v2/$repo/tags/list | jq -r '.tags[]'
  echo ""
done

# Check if specific image:tag exists
curl -s -o /dev/null -w "%{http_code}" http://localhost:30500/v2/knative-activator/manifests/v1.15.0
# Returns: 200 if exists, 404 if not
```

### Test image pull

```bash
# Pull from registry
docker pull localhost:30500/knative-activator:v1.15.0

# Verify it worked
docker images | grep localhost:30500/knative-activator
```

## Registry Management

### Check registry health

```bash
# Check if registry is responding
curl http://localhost:30500/v2/

# Check registry pod
kubectl get pods -n registry

# Check registry logs
kubectl logs -n registry deployment/registry

# Check registry service
kubectl get svc -n registry
```

### Backup registry contents

```bash
# Export all images
mkdir -p registry-backup

for image in $(curl -s http://localhost:30500/v2/_catalog | jq -r '.repositories[]'); do
  for tag in $(curl -s http://localhost:30500/v2/$image/tags/list | jq -r '.tags[]'); do
    echo "Saving $image:$tag"
    docker pull localhost:30500/$image:$tag
    docker save localhost:30500/$image:$tag -o registry-backup/${image//\//_}_${tag}.tar
  done
done
```

### Restore registry contents

```bash
# Load and push images
for tarfile in registry-backup/*.tar; do
  echo "Loading $tarfile"
  docker load -i "$tarfile"
done

# Push to new registry
NEW_REGISTRY="new-registry:5000"
for image in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep localhost:30500); do
  NEW_IMAGE="${image/localhost:30500/$NEW_REGISTRY}"
  docker tag "$image" "$NEW_IMAGE"
  docker push "$NEW_IMAGE"
done
```

## Troubleshooting

### Can't connect to registry

```bash
# Check if registry pod is running
kubectl get pods -n registry

# Check service
kubectl get svc registry -n registry

# Test from within cluster
kubectl run -it --rm test --image=curlimages/curl --restart=Never -- curl http://registry.registry.svc.cluster.local:5000/v2/
```

### Image push fails

```bash
# Check registry logs
kubectl logs -n registry deployment/registry --tail=50

# Check if registry allows push (it should by default)
# Check PVC space
kubectl get pvc -n registry
```

### Web UI shows empty registry

```bash
# Check UI logs
kubectl logs -n registry deployment/registry-ui

# Verify REGISTRY_URL environment variable
kubectl get deployment registry-ui -n registry -o jsonpath='{.spec.template.spec.containers[0].env}'

# Test API from UI pod
kubectl exec -n registry deployment/registry-ui -- curl http://registry.registry.svc.cluster.local:5000/v2/_catalog
```

## Summary

**Current Setup:**
- ✅ Docker Registry v2 running at `localhost:30500`
- ✅ 10 Knative images stored
- ✅ Command-line browsing via `browse-registry.sh`
- ✅ API access via curl

**Optional Additions:**
- 🔲 Web UI (install with script above)
- 🔲 Authentication (can be added)
- 🔲 TLS/HTTPS (can be added)

**For Production:**
- Consider Harbor for full-featured registry
- Add authentication and authorization
- Enable HTTPS/TLS
- Set up image scanning
- Configure backup/restore procedures
