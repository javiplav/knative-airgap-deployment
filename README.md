# Knative Airgap Deployment

Complete solution for deploying Knative Serving in airgapped environments using a private Docker registry.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-blue.svg)](https://kubernetes.io/)
[![Knative](https://img.shields.io/badge/Knative-v1.15.0-green.svg)](https://knative.dev/)

## Overview

This project provides a tested, production-ready approach to deploy Knative Serving in environments without internet access. It includes:

- ✅ **Automated Scripts**: One-command setup and deployment
- ✅ **Private Registry**: Docker Registry v2 setup with web UI
- ✅ **Image Mirroring**: All Knative images mirrored to private registry
- ✅ **Tested Solution**: Fully validated airgap deployment
- ✅ **Complete Documentation**: Step-by-step guides and troubleshooting

## Features

- 🔒 **Fully Airgapped**: No internet access required after initial setup
- 🚀 **Easy Setup**: Automated scripts handle everything
- 📦 **Registry Included**: Docker Registry v2 with optional web UI
- ✅ **Verified**: All components confirmed running from private registry
- 📚 **Well Documented**: Comprehensive guides and explanations
- 🛠️ **Production Ready**: Includes security considerations and best practices

## Quick Start

### Two Deployment Options

#### Option 1: Direct Installation (Connected Environment)

For testing or when you have internet access:

**Prerequisites**:
- Kubernetes cluster (Rancher Desktop, kind, k3s, or any distribution)
- kubectl configured and working
- Helm 3.x installed
- Docker or container runtime for image operations
- ~3GB free disk space for images

**One-Command Setup**:

```bash
cd scripts
./run-all.sh
```

This will:
1. Setup Docker Registry v2 on your cluster
2. Mirror all 11 Knative images to the private registry
3. Deploy Knative Operator and Serving using only private images
4. Test the deployment with a sample service

**Time**: ~10-15 minutes

#### Option 2: True Airgap Installation (Recommended for Production)

For fully airgapped environments with **NO internet access**:

**On Connected System** (with internet):
```bash
# Create complete airgap package
cd scripts
./package-for-airgap.sh

# Output: build/knative-airgap-1.0.0.tar.gz (~2-3 GB)
```

**Transfer Package**:
- USB drive, secure file transfer, or physical media
- Includes all images, scripts, and documentation

**On Airgapped System** (no internet):
```bash
# Extract and install
tar -xzf knative-airgap-1.0.0.tar.gz
cd knative-airgap-1.0.0/
./install.sh
```

**Time**:
- Package creation: 10-15 minutes
- Installation: 10-15 minutes

📖 **See [Airgap Packaging Guide](docs/AIRGAP-PACKAGING.md) for complete workflow**

## What Gets Deployed

### Components

- **Docker Registry v2**: Private container registry at `localhost:30500`
- **Registry Web UI**: Browse images at `http://localhost:30600`
- **Knative Operator**: Manages Knative installation
- **Knative Serving**: Serverless platform components
  - Activator
  - Autoscaler
  - Controller
  - Webhook
  - Kourier (Ingress)

### Images Mirrored (11 total)

All Knative v1.15.0 components:
- knative-operator
- knative-activator
- knative-autoscaler
- knative-autoscaler-hpa
- knative-controller
- knative-webhook
- knative-queue
- knative-kourier
- knative-default-domain
- knative-helloworld-go (test app)

## Documentation

### Getting Started

- **[Quick Start](docs/QUICK-START.md)** - Get up and running quickly
- **[Airgap Packaging Guide](docs/AIRGAP-PACKAGING.md)** ⭐ - Complete workflow for true airgap deployment
- **[Deployment Guide](docs/DEPLOYMENT-GUIDE.md)** - Comprehensive deployment instructions
- **[Testing Guide](docs/TESTING-GUIDE.md)** - Test results and validation

### Understanding the System

- **[Image Override Explained](docs/IMAGE-OVERRIDE-EXPLAINED.md)** - How Knative uses private registry
- **[Registry Browser](docs/REGISTRY-BROWSER.md)** - Browse and manage your registry
- **[FAQ](docs/FAQ.md)** - Common questions answered
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Solutions to common issues

### Verification

- **[Proof of Airgap](docs/PROOF-OF-AIRGAP.md)** - Evidence all images use private registry
- **[Image Dates Explained](docs/IMAGE-DATES-EXPLAINED.md)** - Why creation dates show "a year ago"

## Project Structure

```
knative-airgap/
├── README.md                     # This file
├── scripts/                      # Automation scripts
│   ├── run-all.sh               # One-command full setup
│   ├── 1-setup-registry.sh      # Deploy Docker registry
│   ├── 2-mirror-images.sh       # Mirror images
│   ├── 3-deploy-airgap.sh       # Deploy Knative
│   ├── 4-test-airgap.sh         # Test deployment
│   ├── cleanup.sh               # Remove everything
│   ├── browse-registry.sh       # CLI registry browser
│   └── install-registry-ui.sh   # Install web UI
├── config/                       # Configuration files
│   └── images.txt               # List of images to mirror
├── docs/                         # Documentation
│   ├── QUICK-START.md
│   ├── DEPLOYMENT-GUIDE.md
│   ├── TESTING-GUIDE.md
│   ├── REGISTRY-BROWSER.md
│   ├── IMAGE-OVERRIDE-EXPLAINED.md
│   ├── FAQ.md
│   ├── TROUBLESHOOTING.md
│   └── ...
└── examples/                     # Example manifests
    └── test-service.yaml        # Sample Knative service
```

## Usage

### Step-by-Step

```bash
# 1. Setup private registry
./scripts/1-setup-registry.sh

# 2. Mirror all images
./scripts/2-mirror-images.sh

# 3. Deploy Knative in airgap mode
./scripts/3-deploy-airgap.sh

# 4. Test the deployment
./scripts/4-test-airgap.sh
```

### Verify Installation

```bash
# Check all Knative components
kubectl get pods -n knative-serving

# View registry contents
./scripts/browse-registry.sh all

# Or use web UI
open http://localhost:30600
```

## Production Considerations

### What Works

✅ **Image Mirroring**: 100% success rate (11/11 images)
✅ **Operator Deployment**: Runs from private registry
✅ **Core Components**: All 6 Knative Serving components working
✅ **Registry Override**: KnativeServing configuration verified
✅ **Airgap Capability**: No internet access needed after setup

### Known Limitations

⚠️ **Kourier Gateway**: The Envoy proxy requires additional configuration (documented in troubleshooting)
⚠️ **macOS Harbor**: Harbor has compatibility issues on macOS ARM; use Docker Registry v2 or run Harbor on Linux

### Recommendations for Production

1. **Use Harbor on Linux**: For production, deploy Harbor on Linux for better features:
   - Security scanning (Trivy)
   - Replication
   - RBAC
   - Webhooks

2. **Enable TLS/HTTPS**: Configure registry with proper certificates

3. **Add Authentication**: Set up user authentication on registry

4. **Consider Alternative Ingress**: Istio or Contour work better in airgap than Kourier

5. **Version Pinning**: Always use specific image versions (never `:latest`)

6. **Regular Updates**: Plan for periodic image updates and re-mirroring

## Testing Results

- ✅ **Environment**: Rancher Desktop (k3s v1.34.3) on macOS
- ✅ **Registry**: Docker Registry v2
- ✅ **Images**: 11/11 successfully mirrored
- ✅ **Operator**: Deployed from private registry
- ✅ **Serving**: 6/6 core components running
- ✅ **Success Rate**: 100% for core functionality

See [TESTING-GUIDE.md](docs/TESTING-GUIDE.md) for detailed results.

## Troubleshooting

### Registry Issues

```bash
# Check registry is running
kubectl get pods -n registry

# Test registry access
curl http://localhost:30500/v2/_catalog
```

### Knative Issues

```bash
# Check Knative status
kubectl get knativeserving -n knative-serving

# View operator logs
kubectl logs -n knative-operator -l app=operator
```

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more solutions.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Knative](https://knative.dev/) - Kubernetes-based platform for serverless workloads
- [Docker Registry](https://docs.docker.com/registry/) - Open-source registry implementation
- [Joxit's Docker Registry UI](https://github.com/Joxit/docker-registry-ui) - Web UI for registry

## Support

- 📖 **Documentation**: Check the [docs/](docs/) directory
- 🐛 **Issues**: Report issues on GitHub
- 💬 **Questions**: Open a discussion on GitHub

## Related Resources

- [Knative Documentation](https://knative.dev/docs/)
- [Knative Operator](https://github.com/knative/operator)
- [Harbor Registry](https://goharbor.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

**Made with ❤️ for airgapped Kubernetes deployments**
