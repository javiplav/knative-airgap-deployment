#!/bin/bash
set -e

# Package everything for airgapped deployment
# This script must be run on a CONNECTED system with internet access

VERSION="1.0.0"
PACKAGE_NAME="knative-airgap-${VERSION}"
BUILD_DIR="build/${PACKAGE_NAME}"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║   Knative Airgap - Package Builder for Airgapped Deployment     ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Version: ${VERSION}"
echo "Package: ${PACKAGE_NAME}.tar.gz"
echo ""
echo "This will create a complete package for airgapped installation."
echo "Time: ~10-15 minutes (downloading images)"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Check prerequisites
echo ""
echo "Step 1: Checking prerequisites..."

if ! command -v docker &> /dev/null && ! command -v nerdctl &> /dev/null; then
    echo "❌ Error: Docker or nerdctl required"
    exit 1
fi

if command -v docker &> /dev/null; then
    CTR="docker"
else
    CTR="nerdctl"
fi

if ! command -v jq &> /dev/null; then
    echo "⚠️  Warning: jq not found, continuing without it"
fi

echo "✓ Using container runtime: ${CTR}"

# Create build directory
echo ""
echo "Step 2: Creating package structure..."
rm -rf build
mkdir -p "${BUILD_DIR}"/{scripts,config,docs,examples,images}

# Copy project files
echo "  - Copying scripts..."
cp -r ../scripts/*.sh "${BUILD_DIR}/scripts/"
chmod +x "${BUILD_DIR}/scripts/"*.sh

echo "  - Copying configuration..."
cp -r ../config/* "${BUILD_DIR}/config/"

echo "  - Copying documentation..."
cp -r ../docs/* "${BUILD_DIR}/docs/"
cp ../README.md ../LICENSE ../CONTRIBUTING.md "${BUILD_DIR}/"

echo "  - Copying examples..."
cp -r ../examples/* "${BUILD_DIR}/examples/"

echo "✓ Project files copied"

# Pull and save all images
echo ""
echo "Step 3: Downloading and saving container images..."
echo "  This will take several minutes..."
echo ""

IMAGES_FILE="../config/images.txt"
if [ ! -f "$IMAGES_FILE" ]; then
    echo "❌ Error: images.txt not found"
    exit 1
fi

TOTAL=$(grep -v '^#' "$IMAGES_FILE" | grep -v '^$' | wc -l | tr -d ' ')
CURRENT=0
FAILED=0

while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue

    CURRENT=$((CURRENT + 1))
    IMAGE="$line"

    # Create safe filename
    SAFE_NAME=$(echo "$IMAGE" | tr '/:' '_')
    TAR_FILE="${BUILD_DIR}/images/${SAFE_NAME}.tar"

    echo "[$CURRENT/$TOTAL] $IMAGE"
    echo "  - Pulling..."

    if ! $CTR pull "$IMAGE" 2>&1 | grep -v "Pulling from"; then
        echo "  ❌ Failed to pull $IMAGE"
        FAILED=$((FAILED + 1))
        continue
    fi

    echo "  - Saving to tar..."
    if ! $CTR save "$IMAGE" -o "$TAR_FILE" 2>&1; then
        echo "  ❌ Failed to save $IMAGE"
        FAILED=$((FAILED + 1))
        continue
    fi

    SIZE=$(du -h "$TAR_FILE" | cut -f1)
    echo "  ✓ Saved ($SIZE)"
    echo ""
done < "$IMAGES_FILE"

echo "Image export complete: $((TOTAL - FAILED))/$TOTAL successful"

if [ $FAILED -gt 0 ]; then
    echo "⚠️  Warning: $FAILED images failed to download"
    echo "    The package will work but may be incomplete"
fi

# Create installation script
echo ""
echo "Step 4: Creating installation script..."

cat > "${BUILD_DIR}/install.sh" << 'INSTALL_EOF'
#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║      Knative Airgap - Installation in Airgapped Environment     ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "This script will install Knative in your airgapped environment."
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl not found. Please install kubectl first."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot connect to Kubernetes cluster."
    echo "   Please configure kubectl to connect to your cluster."
    exit 1
fi

if ! command -v docker &> /dev/null && ! command -v nerdctl &> /dev/null; then
    echo "❌ Error: Docker or nerdctl required for loading images"
    exit 1
fi

if command -v docker &> /dev/null; then
    CTR="docker"
else
    CTR="nerdctl"
fi

echo "✓ Prerequisites met"
echo ""

# Load all images
echo "Step 1: Loading container images..."
echo "  This will take several minutes..."
echo ""

IMAGE_COUNT=$(ls -1 images/*.tar 2>/dev/null | wc -l | tr -d ' ')

if [ "$IMAGE_COUNT" -eq 0 ]; then
    echo "❌ Error: No image tar files found in images/"
    exit 1
fi

CURRENT=0
LOADED=0
FAILED=0

for tar_file in images/*.tar; do
    CURRENT=$((CURRENT + 1))
    filename=$(basename "$tar_file")

    echo "[$CURRENT/$IMAGE_COUNT] Loading $filename..."

    if $CTR load -i "$tar_file" 2>&1 | tail -1; then
        LOADED=$((LOADED + 1))
    else
        echo "  ⚠️  Failed to load $filename"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "✓ Images loaded: $LOADED/$IMAGE_COUNT"

if [ $FAILED -gt 0 ]; then
    echo "⚠️  Warning: $FAILED images failed to load"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Run installation
echo ""
echo "Step 2: Installing Knative..."
echo ""

cd scripts

# Make scripts executable
chmod +x *.sh

# Run the installation
./run-all.sh

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    Installation Complete!                        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Verify installation:"
echo "     kubectl get pods -n knative-serving"
echo ""
echo "  2. Access registry UI:"
echo "     http://localhost:30600"
echo ""
echo "  3. Deploy test service:"
echo "     kubectl apply -f examples/test-service.yaml"
echo ""
echo "For more information, see README.md"
echo ""
INSTALL_EOF

chmod +x "${BUILD_DIR}/install.sh"

echo "✓ Installation script created"

# Create README for the package
echo ""
echo "Step 5: Creating package README..."

cat > "${BUILD_DIR}/README-PACKAGE.md" << 'README_EOF'
# Knative Airgap Installation Package

This package contains everything needed to deploy Knative Serving in an airgapped environment.

## Package Contents

- **scripts/** - Installation and management scripts
- **images/** - All container images as tar files (~2-3 GB)
- **config/** - Configuration files
- **docs/** - Complete documentation
- **examples/** - Example Knative services
- **install.sh** - Main installation script

## Quick Installation

### Prerequisites (In Airgapped Environment)

1. **Kubernetes cluster** (any distribution)
2. **kubectl** configured and working
3. **Docker or nerdctl** for loading images
4. **6-8 GB RAM** recommended
5. **4 CPU cores** recommended

### Installation Steps

```bash
# 1. Extract the package
tar -xzf knative-airgap-*.tar.gz
cd knative-airgap-*/

# 2. Run the installation script
./install.sh
```

That's it! The script will:
- Load all container images
- Setup Docker Registry v2
- Deploy Knative Operator
- Deploy Knative Serving
- Test the installation

**Time**: ~10-15 minutes

### Verify Installation

```bash
# Check Knative pods
kubectl get pods -n knative-serving

# Check registry
kubectl get pods -n registry

# Access web UI
open http://localhost:30600
```

### Deploy Your First Service

```bash
kubectl apply -f examples/test-service.yaml
kubectl get ksvc
```

## Manual Installation

If you prefer step-by-step:

```bash
cd scripts

# 1. Setup private registry
./1-setup-registry.sh

# 2. Mirror images (they're already loaded in Docker)
./2-mirror-images.sh

# 3. Deploy Knative
./3-deploy-airgap.sh

# 4. Test
./4-test-airgap.sh
```

## Documentation

Full documentation is in the `docs/` directory:

- **Quick Start**: docs/QUICK-START.md
- **Deployment Guide**: docs/DEPLOYMENT-GUIDE.md
- **FAQ**: docs/FAQ.md
- **Troubleshooting**: docs/TROUBLESHOOTING.md

## Cleanup

To remove everything:

```bash
cd scripts
./cleanup.sh
```

## Support

See documentation in `docs/` directory or check:
- docs/FAQ.md
- docs/TROUBLESHOOTING.md

## Version

Package Version: 1.0.0
Knative Version: v1.15.0
Generated: $(date)

---

For the latest version and updates, visit:
https://github.com/your-username/knative-airgap-deployment
README_EOF

echo "✓ Package README created"

# Create manifest file
echo ""
echo "Step 6: Creating manifest..."

cat > "${BUILD_DIR}/MANIFEST.txt" << MANIFEST_EOF
Knative Airgap Installation Package
====================================

Package Version: ${VERSION}
Knative Version: v1.15.0
Build Date: $(date)
Build System: $(uname -s) $(uname -m)

Contents:
---------
- Installation script (install.sh)
- Scripts ($(ls -1 "${BUILD_DIR}/scripts" | wc -l | tr -d ' ') files)
- Container images ($(ls -1 "${BUILD_DIR}/images" 2>/dev/null | wc -l | tr -d ' ') tar files)
- Documentation ($(ls -1 "${BUILD_DIR}/docs" | wc -l | tr -d ' ') files)
- Examples ($(ls -1 "${BUILD_DIR}/examples" | wc -l | tr -d ' ') files)

Image List:
-----------
MANIFEST_EOF

while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    echo "  - $line" >> "${BUILD_DIR}/MANIFEST.txt"
done < "$IMAGES_FILE"

cat >> "${BUILD_DIR}/MANIFEST.txt" << MANIFEST_EOF

Total Package Size: $(du -sh "${BUILD_DIR}" | cut -f1)

Checksums:
----------
MANIFEST_EOF

# Generate checksums for images
cd "${BUILD_DIR}/images"
if command -v sha256sum &> /dev/null; then
    sha256sum *.tar >> ../MANIFEST.txt 2>/dev/null || echo "Checksum generation skipped" >> ../MANIFEST.txt
elif command -v shasum &> /dev/null; then
    shasum -a 256 *.tar >> ../MANIFEST.txt 2>/dev/null || echo "Checksum generation skipped" >> ../MANIFEST.txt
fi
cd - > /dev/null

echo "✓ Manifest created"

# Create the final tar package
echo ""
echo "Step 7: Creating compressed package..."

cd build
tar -czf "${PACKAGE_NAME}.tar.gz" "${PACKAGE_NAME}/"

PACKAGE_SIZE=$(du -h "${PACKAGE_NAME}.tar.gz" | cut -f1)
PACKAGE_PATH="$(pwd)/${PACKAGE_NAME}.tar.gz"

echo "✓ Package created: ${PACKAGE_SIZE}"

# Cleanup build directory (keep only tar.gz)
echo ""
echo "Step 8: Cleaning up..."
rm -rf "${PACKAGE_NAME}"
echo "✓ Build directory cleaned"

# Final summary
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                      Package Complete!                           ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Package Location:"
echo "  ${PACKAGE_PATH}"
echo ""
echo "Package Size: ${PACKAGE_SIZE}"
echo ""
echo "Next Steps:"
echo "  1. Transfer package to airgapped environment:"
echo "     - USB drive"
echo "     - Secure file transfer"
echo "     - Physical media"
echo ""
echo "  2. In airgapped environment:"
echo "     tar -xzf ${PACKAGE_NAME}.tar.gz"
echo "     cd ${PACKAGE_NAME}/"
echo "     ./install.sh"
echo ""
echo "Contents:"
echo "  - All Knative container images (${TOTAL} images)"
echo "  - Installation scripts"
echo "  - Complete documentation"
echo "  - Example manifests"
echo ""
echo "For transfer, you can also generate checksums:"
echo "  sha256sum ${PACKAGE_NAME}.tar.gz > ${PACKAGE_NAME}.tar.gz.sha256"
echo ""
