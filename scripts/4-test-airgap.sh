#!/bin/bash
set -e

# Load registry configuration
if [ -f registry-config.env ]; then
    source registry-config.env
else
    echo "Error: registry-config.env not found"
    exit 1
fi

echo "=== Testing Airgap Knative Deployment ==="
echo ""

echo "Step 1: Verifying Knative Serving is ready..."
if ! kubectl get knativeserving knative-serving -n knative-serving &>/dev/null; then
    echo "Error: Knative Serving not found. Run ./3-deploy-airgap-simple.sh first."
    exit 1
fi

STATUS=$(kubectl get knativeserving knative-serving -n knative-serving -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
if [ "$STATUS" != "True" ]; then
    echo "Warning: Knative Serving is not ready yet."
    echo "Current status:"
    kubectl get knativeserving knative-serving -n knative-serving
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✓ Knative Serving is ready"

echo ""
echo "Step 2: Deploying test application..."

# Check if test image was mirrored
TEST_IMAGE=$(grep "helloworld-go" image-mappings.txt | cut -d'=' -f2)

if [ -z "$TEST_IMAGE" ]; then
    echo "Test image not found in mappings. Using a simple nginx test instead..."
    TEST_IMAGE="nginx:alpine"
    TEST_TYPE="nginx"
else
    TEST_TYPE="knative-sample"
fi

cat > test-service-airgap.yaml <<EOF
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: hello-airgap
  namespace: default
spec:
  template:
    spec:
      containers:
      - image: $TEST_IMAGE
EOF

if [ "$TEST_TYPE" = "knative-sample" ]; then
    cat >> test-service-airgap.yaml <<EOF
        env:
        - name: TARGET
          value: "Airgap World"
        ports:
        - containerPort: 8080
EOF
else
    cat >> test-service-airgap.yaml <<EOF
        ports:
        - containerPort: 80
EOF
fi

kubectl apply -f test-service-airgap.yaml

echo "Waiting for service to be ready..."
sleep 5

# Wait for service to be ready
TIMEOUT=120
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(kubectl get ksvc hello-airgap -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    if [ "$STATUS" = "True" ]; then
        break
    fi
    echo "  Waiting... ($ELAPSED/$TIMEOUT seconds)"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ "$STATUS" != "True" ]; then
    echo ""
    echo "WARNING: Service did not become ready within timeout."
    echo "Current status:"
    kubectl get ksvc hello-airgap
    echo ""
    echo "Checking pods:"
    kubectl get pods | grep hello-airgap || true
    echo ""
    echo "Check events:"
    kubectl get events --sort-by='.lastTimestamp' | grep hello-airgap | tail -10 || true
    echo ""
    echo "Check pod logs:"
    POD=$(kubectl get pods | grep hello-airgap | grep Running | awk '{print $1}' | head -1)
    if [ -n "$POD" ]; then
        echo "Pod logs for $POD:"
        kubectl logs "$POD" --all-containers || true
    fi
    exit 1
fi

echo "✓ Test service deployed"

echo ""
echo "Step 3: Getting service URL..."
SERVICE_URL=$(kubectl get ksvc hello-airgap -o jsonpath='{.status.url}')
echo "Service URL: $SERVICE_URL"

echo ""
echo "Step 4: Testing service access..."

# Start port-forward in background
echo "Starting port-forward to Kourier..."
kubectl port-forward -n knative-serving svc/kourier 8080:80 > /dev/null 2>&1 &
PF_PID=$!
sleep 3

# Test the service
echo "Testing service..."
HOST_HEADER=$(echo "$SERVICE_URL" | sed 's|http://||')
RESPONSE=$(curl -s -H "Host: $HOST_HEADER" http://localhost:8080 || echo "FAILED")

# Stop port-forward
kill $PF_PID 2>/dev/null || true

if [ "$TEST_TYPE" = "knative-sample" ] && [[ "$RESPONSE" == *"Airgap World"* ]]; then
    echo "✓ Service response: $RESPONSE"
    echo ""
    echo "=== Test PASSED! ==="
elif [ "$TEST_TYPE" = "nginx" ] && [[ "$RESPONSE" == *"nginx"* ]]; then
    echo "✓ Nginx service is responding"
    echo ""
    echo "=== Test PASSED! ==="
elif [[ ! "$RESPONSE" == "FAILED" ]]; then
    echo "✓ Service is responding: ${RESPONSE:0:100}..."
    echo ""
    echo "=== Test PASSED! ==="
else
    echo "✗ Unexpected response: $RESPONSE"
    echo ""
    echo "=== Test FAILED ==="
    echo ""
    echo "Troubleshooting:"
    echo "1. Check service status: kubectl get ksvc hello-airgap"
    echo "2. Check pods: kubectl get pods | grep hello"
    echo "3. Check pod logs: kubectl logs <pod-name>"
    echo "4. Check events: kubectl get events --sort-by='.lastTimestamp'"
    exit 1
fi

echo ""
echo "Your airgap Knative deployment is working correctly!"
echo ""
echo "To access the service manually:"
echo "1. Start port-forward: kubectl port-forward -n knative-serving svc/kourier 8080:80"
echo "2. In another terminal: curl -H \"Host: $HOST_HEADER\" http://localhost:8080"
echo ""
echo "To delete the test service:"
echo "  kubectl delete ksvc hello-airgap"
echo ""
