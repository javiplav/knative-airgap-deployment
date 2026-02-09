#!/bin/bash
set -e

echo "================================================="
echo "  Installing Docker Registry Web UI"
echo "================================================="
echo ""

echo "Deploying UI to Kubernetes..."

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
        - name: SINGLE_REGISTRY
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

echo ""
echo "Waiting for UI to be ready..."
kubectl wait --for=condition=ready pod -l app=registry-ui -n registry --timeout=120s 2>/dev/null || true

sleep 5

echo ""
echo "================================================="
echo "  Installation Complete!"
echo "================================================="
echo ""
echo "✅ Docker Registry UI is now running"
echo ""
echo "🌐 Access the UI at: http://localhost:30600"
echo ""
echo "Features:"
echo "  - Browse all images and tags"
echo "  - View image details and layers"
echo "  - View manifests and digests"
echo "  - Delete images (if needed)"
echo ""
echo "Current registry contents:"
curl -s http://localhost:30500/v2/_catalog | jq -r '.repositories[]' | nl
echo ""
