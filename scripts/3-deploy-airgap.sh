#!/bin/bash
set -e

# Load registry configuration
if [ -f registry-config.env ]; then
    source registry-config.env
    echo "Loaded registry configuration from registry-config.env"
else
    echo "Error: registry-config.env not found. Run ./1-setup-registry-simple.sh first."
    exit 1
fi

echo "=== Deploying Knative in Airgap Mode ==="
echo ""
echo "Using private registry: $REGISTRY_URL"
echo "Project prefix: $REGISTRY_PROJECT"
echo ""

# Check if image mappings exist
if [ ! -f image-mappings.txt ]; then
    echo "Error: image-mappings.txt not found. Run ./2-mirror-images-simple.sh first."
    exit 1
fi

echo "Step 1: Downloading and modifying Knative Operator manifest..."

# Download original manifest
curl -sL https://github.com/knative/operator/releases/download/knative-v1.15.0/operator.yaml -o operator-original.yaml

# Create modified manifest with private registry
# Extract image names and tags from mappings
OPERATOR_IMG=$(grep "operator/cmd/operator" image-mappings.txt | cut -d'=' -f2)
WEBHOOK_IMG=$(grep "operator/cmd/webhook" image-mappings.txt | cut -d'=' -f2)

cat operator-original.yaml | \
  sed "s|gcr.io/knative-releases/knative.dev/operator/cmd/operator:v1.15.0|$OPERATOR_IMG|g" | \
  sed "s|gcr.io/knative-releases/knative.dev/operator/cmd/webhook:v1.15.0|$WEBHOOK_IMG|g" \
  > operator-airgap.yaml

echo "✓ Operator manifest modified and saved to operator-airgap.yaml"

echo ""
echo "Step 2: Deploying Knative Operator..."

# Deploy operator
kubectl apply -f operator-airgap.yaml

# Wait for operator namespace to be created
echo "Waiting for operator namespace..."
sleep 5

echo "Waiting for Operator pods to be ready..."
kubectl wait --for=condition=ready pod -l app=operator -n knative-operator --timeout=300s 2>/dev/null || \
kubectl wait --for=condition=ready pod -n knative-operator --all --timeout=300s

echo "✓ Knative Operator deployed successfully"

echo ""
echo "Step 3: Creating Knative Serving with registry overrides..."

# Create knative-serving namespace
kubectl create namespace knative-serving --dry-run=client -o yaml | kubectl apply -f -

# Extract all serving images from mappings
ACTIVATOR_IMG=$(grep "serving/cmd/activator" image-mappings.txt | cut -d'=' -f2)
AUTOSCALER_IMG=$(grep "serving/cmd/autoscaler:v" image-mappings.txt | cut -d'=' -f2)
AUTOSCALER_HPA_IMG=$(grep "autoscaler-hpa" image-mappings.txt | cut -d'=' -f2)
CONTROLLER_IMG=$(grep "serving/cmd/controller" image-mappings.txt | cut -d'=' -f2)
WEBHOOK_SRV_IMG=$(grep "serving/cmd/webhook" image-mappings.txt | cut -d'=' -f2)
QUEUE_IMG=$(grep "serving/cmd/queue" image-mappings.txt | cut -d'=' -f2)
KOURIER_IMG=$(grep "kourier" image-mappings.txt | cut -d'=' -f2)

# Create KnativeServing with registry overrides
cat > knative-serving-airgap.yaml <<EOF
apiVersion: operator.knative.dev/v1beta1
kind: KnativeServing
metadata:
  name: knative-serving
  namespace: knative-serving
spec:
  version: "1.15.0"

  # Registry configuration - override all images to use private registry
  registry:
    default: $REGISTRY_URL
    override:
      activator: $ACTIVATOR_IMG
      autoscaler: $AUTOSCALER_IMG
      autoscaler-hpa: $AUTOSCALER_HPA_IMG
      controller: $CONTROLLER_IMG
      webhook: $WEBHOOK_SRV_IMG
      queue-proxy: $QUEUE_IMG
      net-kourier-controller/controller: $KOURIER_IMG

  # Enable Kourier ingress
  ingress:
    kourier:
      enabled: true

  # Network configuration
  config:
    network:
      ingress-class: "kourier.ingress.networking.knative.dev"
    domain:
      127.0.0.1.sslip.io: ""
    deployment:
      registriesSkippingTagResolving: "$REGISTRY_URL"
EOF

echo "Applying KnativeServing manifest..."
kubectl apply -f knative-serving-airgap.yaml

echo ""
echo "Step 4: Waiting for Knative Serving to be ready..."
echo "This may take 3-5 minutes..."

# Wait for KnativeServing to be ready
kubectl wait --for=condition=Ready knativeserving/knative-serving -n knative-serving --timeout=600s || {
    echo ""
    echo "WARNING: Timeout waiting for Knative Serving."
    echo "Checking current status..."
    kubectl get knativeserving -n knative-serving
    kubectl get pods -n knative-serving
    echo ""
    echo "Check logs with:"
    echo "  kubectl logs -n knative-operator -l app=operator"
    echo "  kubectl describe knativeserving knative-serving -n knative-serving"
    exit 1
}

echo "✓ Knative Serving deployed successfully"

echo ""
echo "Step 5: Verifying installation..."
echo ""
echo "Knative Operator:"
kubectl get pods -n knative-operator

echo ""
echo "Knative Serving:"
kubectl get pods -n knative-serving

echo ""
echo "Knative Serving Status:"
kubectl get knativeserving -n knative-serving

echo ""
echo "=== Deployment Complete! ==="
echo ""
echo "Your airgap Knative deployment is ready!"
echo ""
echo "Test the deployment with:"
echo "  ./4-test-airgap-simple.sh"
echo ""
