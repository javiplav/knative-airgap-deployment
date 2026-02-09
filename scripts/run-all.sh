#!/bin/bash
set -e

echo "======================================"
echo "  Knative Airgap Setup - Simple"
echo "======================================"
echo ""
echo "Using lightweight Docker Registry v2"
echo ""
echo "This script will:"
echo "  1. Setup Docker registry on Kubernetes"
echo "  2. Mirror all Knative images to registry"
echo "  3. Deploy Knative in airgap mode"
echo "  4. Test the deployment"
echo ""
echo "Estimated time: 10-15 minutes"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Make scripts executable
chmod +x *-simple.sh

echo ""
echo "======================================"
echo "Phase 1: Setting up Docker Registry"
echo "======================================"
echo ""
./1-setup-registry-simple.sh

echo ""
echo "Waiting for registry to be fully stable..."
sleep 5

echo ""
echo "======================================"
echo "Phase 2: Mirroring Images"
echo "======================================"
echo ""
./2-mirror-images-simple.sh

echo ""
echo "Waiting for images to settle..."
sleep 5

echo ""
echo "======================================"
echo "Phase 3: Deploying in Airgap Mode"
echo "======================================"
echo ""

# First remove existing Knative if any
echo "Removing existing Knative installation (if any)..."
kubectl delete ksvc hello hello-airgap --ignore-not-found=true 2>/dev/null || true
kubectl delete knativeserving knative-serving -n knative-serving --ignore-not-found=true --timeout=60s 2>/dev/null || true
kubectl delete namespace knative-serving --ignore-not-found=true --timeout=60s 2>/dev/null || true
kubectl delete namespace knative-operator --ignore-not-found=true --timeout=60s 2>/dev/null || true

echo "Waiting for cleanup to complete..."
sleep 10

./3-deploy-airgap-simple.sh

echo ""
echo "======================================"
echo "Phase 4: Testing Deployment"
echo "======================================"
echo ""
sleep 5
./4-test-airgap-simple.sh

echo ""
echo "======================================"
echo "     Setup Complete!"
echo "======================================"
echo ""
echo "Your airgap Knative environment is ready!"
echo ""
echo "Resources created:"
echo "  - Docker Registry v2"
echo "  - Mirrored Knative images"
echo "  - Knative Operator (from private registry)"
echo "  - Knative Serving (from private registry)"
echo "  - Test application (verified working)"
echo ""
source registry-config.env
echo "Registry: $REGISTRY_URL"
echo "  Test: curl http://$REGISTRY_URL/v2/_catalog"
echo ""
echo "Next steps:"
echo "  - View registry catalog: curl http://$REGISTRY_URL/v2/_catalog"
echo "  - Check Knative services: kubectl get ksvc"
echo "  - Deploy your own apps using the private registry"
echo "  - Review AIRGAP-DEPLOYMENT-GUIDE.md for production deployment"
echo ""
echo "To clean up everything:"
echo "  ./0-cleanup-simple.sh"
echo ""
