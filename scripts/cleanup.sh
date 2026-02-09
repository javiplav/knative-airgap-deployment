#!/bin/bash

echo "=== Cleanup Script (Simple Registry) ==="
echo ""
echo "This will remove:"
echo "  - Knative Serving"
echo "  - Knative Operator"
echo "  - Docker Registry"
echo "  - Test services"
echo ""
read -p "Are you sure you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""
echo "Cleaning up test services..."
kubectl delete ksvc hello hello-airgap --ignore-not-found=true

echo ""
echo "Cleaning up Knative Serving..."
kubectl delete knativeserving knative-serving -n knative-serving --ignore-not-found=true --timeout=60s

echo "Waiting for Knative Serving to be removed..."
kubectl wait --for=delete namespace/knative-serving --timeout=120s 2>/dev/null || \
kubectl delete namespace knative-serving --force --grace-period=0 2>/dev/null || true

echo ""
echo "Cleaning up Knative Operator..."
kubectl delete -f operator-airgap.yaml --ignore-not-found=true 2>/dev/null || \
kubectl delete -f operator-original.yaml --ignore-not-found=true 2>/dev/null || \
kubectl delete namespace knative-operator --ignore-not-found=true --timeout=60s

echo ""
echo "Cleaning up Docker Registry..."
kubectl delete namespace registry --ignore-not-found=true --timeout=120s 2>/dev/null || true

echo ""
echo "Cleaning up generated files..."
rm -f operator-original.yaml operator-airgap.yaml knative-serving-airgap.yaml test-service-airgap.yaml
rm -f registry-config.env image-mappings.txt

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "To start fresh, run:"
echo "  ./run-all-simple.sh"
echo ""
