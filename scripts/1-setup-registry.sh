#!/bin/bash
set -e

echo "=== Setting up Simple Docker Registry on Kubernetes ==="

# Check if kubectl is working
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster."
    exit 1
fi

echo ""
echo "Step 1: Creating registry namespace..."
kubectl create namespace registry --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Step 2: Deploying Docker Registry..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-pvc
  namespace: registry
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry
  template:
    metadata:
      labels:
        app: registry
    spec:
      containers:
      - name: registry
        image: registry:2
        ports:
        - containerPort: 5000
        env:
        - name: REGISTRY_STORAGE_DELETE_ENABLED
          value: "true"
        volumeMounts:
        - name: registry-data
          mountPath: /var/lib/registry
      volumes:
      - name: registry-data
        persistentVolumeClaim:
          claimName: registry-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: registry
  namespace: registry
spec:
  type: NodePort
  selector:
    app: registry
  ports:
  - protocol: TCP
    port: 5000
    targetPort: 5000
    nodePort: 30500
EOF

echo ""
echo "Step 3: Waiting for registry to be ready..."
kubectl wait --for=condition=ready pod -l app=registry -n registry --timeout=120s

echo ""
echo "Step 4: Getting access information..."
NODEPORT=$(kubectl get svc registry -n registry -o jsonpath='{.spec.ports[0].nodePort}')
REGISTRY_URL="localhost:$NODEPORT"

echo ""
echo "=== Docker Registry Installation Complete! ==="
echo ""
echo "Registry URL: $REGISTRY_URL"
echo ""
echo "Test the registry:"
echo "  curl http://$REGISTRY_URL/v2/_catalog"
echo ""

# Save config for later scripts
cat > registry-config.env <<EOF
REGISTRY_URL=$REGISTRY_URL
REGISTRY_PROJECT=knative
EOF

echo "Registry configuration saved to registry-config.env"
echo ""
echo "Next step: Run the image mirroring script"
echo "  ./2-mirror-images-simple.sh"
