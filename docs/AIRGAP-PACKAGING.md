# Airgap Packaging and Deployment Guide

Complete guide for preparing, transferring, and installing Knative in a fully airgapped environment.

## Overview

This guide covers the **complete airgap deployment workflow**:

```
┌─────────────────────┐         ┌─────────────────────┐         ┌─────────────────────┐
│  Connected System   │  ──────>│  Transfer Package   │  ──────>│ Airgapped System    │
│                     │         │                     │         │                     │
│  1. Download images │         │  USB/Media/etc      │         │  3. Extract package │
│  2. Create package  │         │                     │         │  4. Run install.sh  │
└─────────────────────┘         └─────────────────────┘         └─────────────────────┘
```

## Part 1: Connected System (Packaging)

### Prerequisites

On a system **WITH internet access**:

- Docker or nerdctl installed
- ~5 GB free disk space
- Internet connection
- This repository cloned

### Create the Airgap Package

```bash
cd knative-airgap/scripts
./package-for-airgap.sh
```

The script will:
1. ✅ Check prerequisites
2. ✅ Download all 11 Knative container images (~2-3 GB)
3. ✅ Save each image as a tar file
4. ✅ Package all scripts, docs, and configs
5. ✅ Create installation script
6. ✅ Generate manifest and checksums
7. ✅ Create compressed tar.gz package

**Time**: 10-15 minutes (depends on internet speed)

**Output**: `build/knative-airgap-1.0.0.tar.gz` (~2-3 GB compressed)

### Package Contents

The generated package includes:

```
knative-airgap-1.0.0/
├── install.sh                    # Main installation script
├── README-PACKAGE.md             # Quick start guide
├── MANIFEST.txt                  # Package contents & checksums
├── scripts/                      # All management scripts
├── images/                       # Container images (11 tar files)
├── config/                       # Configuration
├── docs/                         # Full documentation
└── examples/                     # Example manifests
```

### Verify the Package

```bash
# Check package size
ls -lh build/knative-airgap-*.tar.gz

# Generate checksum for verification
sha256sum build/knative-airgap-*.tar.gz > build/knative-airgap-*.tar.gz.sha256

# View contents without extracting
tar -tzf build/knative-airgap-*.tar.gz | head -20
```

### Package Details

**What's Included**:
- ✅ All 11 Knative v1.15.0 container images
- ✅ Docker Registry v2 container image
- ✅ All automation scripts
- ✅ Complete documentation (9 files)
- ✅ Configuration files
- ✅ Example manifests
- ✅ Installation script

**Not Included** (must exist in airgapped environment):
- Kubernetes cluster
- kubectl
- Docker/nerdctl
- Helm (if using alternative registry setup)

## Part 2: Transfer to Airgapped Environment

### Transfer Methods

Choose based on your security requirements:

#### Option 1: USB Drive (Most Common)

```bash
# Copy package to USB
cp build/knative-airgap-*.tar.gz /Volumes/USB_DRIVE/
cp build/knative-airgap-*.tar.gz.sha256 /Volumes/USB_DRIVE/

# Safely eject
diskutil eject /Volumes/USB_DRIVE
```

#### Option 2: Secure File Transfer

If you have a secure file transfer system:

```bash
# SCP through secure gateway (if available)
scp build/knative-airgap-*.tar.gz secure-gateway:/transfer/

# SFTP
sftp secure-gateway
put build/knative-airgap-*.tar.gz
```

#### Option 3: Physical Media

For highly secure environments:
1. Burn package to CD/DVD
2. Use approved physical media
3. Follow your organization's transfer procedures

#### Option 4: Approved Network Transfer

If there's a one-way data diode or approved transfer mechanism:
- Follow your organization's approved procedures
- Maintain chain of custody documentation
- Verify checksums after transfer

### Security Considerations

**Before Transfer**:
1. ✅ Verify package integrity:
   ```bash
   sha256sum -c build/knative-airgap-*.tar.gz.sha256
   ```

2. ✅ Scan package (if required):
   ```bash
   # Use your organization's security scanning tools
   ```

3. ✅ Document the transfer:
   - Package version
   - Checksum
   - Date/time
   - Transfer method
   - Approver

**Chain of Custody**:
- Maintain documentation
- Log all transfers
- Verify checksums at each step

## Part 3: Airgapped System (Installation)

### Prerequisites in Airgapped Environment

Before starting:

1. **Kubernetes Cluster** running and accessible
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

2. **kubectl** configured
   ```bash
   kubectl version
   ```

3. **Container Runtime** (Docker or nerdctl)
   ```bash
   docker version
   # or
   nerdctl version
   ```

4. **Resources Available**:
   - 6-8 GB RAM
   - 4 CPU cores
   - 10 GB disk space

5. **Permissions**:
   - Create namespaces
   - Create deployments
   - Create services

### Verify Package Integrity

```bash
# After transfer, verify checksum
sha256sum -c knative-airgap-*.tar.gz.sha256

# Should show: knative-airgap-*.tar.gz: OK
```

### Extract Package

```bash
# Extract
tar -xzf knative-airgap-*.tar.gz

# Enter directory
cd knative-airgap-*/

# View contents
ls -la
```

### Run Installation

#### Automated Installation (Recommended)

```bash
# One command installation
./install.sh
```

The script will:
1. ✅ Check prerequisites
2. ✅ Load all container images into Docker/nerdctl (~5 min)
3. ✅ Setup private Docker registry
4. ✅ Mirror images to registry
5. ✅ Deploy Knative Operator
6. ✅ Deploy Knative Serving
7. ✅ Test the installation

**Total Time**: 10-15 minutes

#### Manual Installation (Advanced)

If you prefer control:

```bash
cd scripts

# Step 1: Load all images manually
for tar_file in ../images/*.tar; do
    echo "Loading $(basename $tar_file)..."
    docker load -i "$tar_file"
done

# Step 2: Setup registry
./1-setup-registry.sh

# Step 3: Mirror images
./2-mirror-images.sh

# Step 4: Deploy Knative
./3-deploy-airgap.sh

# Step 5: Test
./4-test-airgap.sh
```

### Verify Installation

```bash
# Check all components
kubectl get pods -n registry
kubectl get pods -n knative-operator
kubectl get pods -n knative-serving

# Check Knative status
kubectl get knativeserving -n knative-serving

# All pods should be Running
```

### Access Registry UI

```bash
# Registry Web UI
open http://localhost:30600

# Or get the URL
echo "Registry UI: http://localhost:$(kubectl get svc registry-ui -n registry -o jsonpath='{.spec.ports[0].nodePort}')"
```

## Troubleshooting

### Package Creation Issues

**Problem**: Image download fails

**Solution**:
```bash
# Check internet connection
ping google.com

# Check Docker is running
docker ps

# Check disk space
df -h

# Re-run packaging script (it will resume)
./package-for-airgap.sh
```

**Problem**: Package too large for transfer media

**Solution**:
```bash
# Split package into chunks
split -b 1G build/knative-airgap-*.tar.gz knative-airgap-part-

# Transfer all parts
# In airgapped environment, recombine:
cat knative-airgap-part-* > knative-airgap-1.0.0.tar.gz
```

### Transfer Issues

**Problem**: Checksum mismatch after transfer

**Solution**:
- Transfer again
- Check transfer method integrity
- Verify no corruption occurred

**Problem**: USB not recognized in airgapped environment

**Solution**:
- Check USB format (use FAT32 or exFAT for compatibility)
- Try different USB port
- Check security policies for USB devices

### Installation Issues

**Problem**: Images fail to load

**Solution**:
```bash
# Check Docker/nerdctl is running
docker ps

# Check available disk space
df -h

# Load individual images manually
docker load -i images/specific-image.tar
```

**Problem**: Kubernetes cluster not accessible

**Solution**:
```bash
# Check kubeconfig
kubectl config view

# Test connection
kubectl cluster-info

# Check current context
kubectl config current-context
```

**Problem**: Registry pod won't start

**Solution**:
```bash
# Check resources
kubectl describe pod -n registry <pod-name>

# Check events
kubectl get events -n registry --sort-by='.lastTimestamp'

# See full troubleshooting guide
cat docs/TROUBLESHOOTING.md
```

## Best Practices

### For Package Creation

1. **Test Before Packaging**:
   - Run `./run-all.sh` on connected system first
   - Verify all images download successfully
   - Check package integrity

2. **Document Everything**:
   - Package version
   - Build date
   - Checksums
   - Transfer method

3. **Maintain Multiple Copies**:
   - Keep backup of package
   - Store checksums separately
   - Document storage location

### For Transfer

1. **Verify at Each Step**:
   - Before transfer (source)
   - After transfer (destination)
   - Before installation

2. **Use Checksums**:
   - Generate on source system
   - Transfer checksum file separately
   - Verify on destination

3. **Follow Procedures**:
   - Use approved transfer methods
   - Maintain chain of custody
   - Document all steps

### For Installation

1. **Test Cluster First**:
   - Verify kubectl works
   - Check resources available
   - Ensure permissions

2. **Run in Steps**:
   - Extract package
   - Verify contents
   - Load images
   - Install components

3. **Validate After Install**:
   - Check all pods running
   - Test registry access
   - Deploy sample service
   - Document any issues

## Advanced Scenarios

### Multiple Airgapped Environments

If deploying to multiple airgapped systems:

1. **Create one package** on connected system
2. **Test in first environment**
3. **Document any environment-specific changes**
4. **Use same package** for other environments
5. **Customize configs** per environment if needed

### Package Updates

When Knative versions update:

1. Update `config/images.txt` with new versions
2. Re-run `package-for-airgap.sh`
3. Transfer new package
4. In airgapped env, run cleanup first:
   ```bash
   cd scripts
   ./cleanup.sh
   ```
5. Install new version

### Custom Images

To include your own images:

1. Add them to `config/images.txt`:
   ```
   your-registry.com/your-app:v1.0.0
   ```
2. Run packaging script
3. Your images will be included

### Different Architectures

For ARM or other architectures:

1. Package on the **same architecture** as target
2. Or use multi-arch images:
   ```
   docker manifest inspect <image> | grep architecture
   ```

## Security Checklist

Before deploying in production:

- [ ] Package verified with checksums
- [ ] Transfer method approved by security team
- [ ] Images scanned for vulnerabilities
- [ ] Chain of custody documented
- [ ] Installation permissions verified
- [ ] Network policies configured
- [ ] Registry secured (TLS, auth)
- [ ] Access logs enabled
- [ ] Backup procedures defined
- [ ] Incident response plan ready

## Appendix: Package Structure

### Complete Package Layout

```
knative-airgap-1.0.0.tar.gz (2-3 GB compressed)
└── knative-airgap-1.0.0/
    ├── install.sh                        # Main installer
    ├── README-PACKAGE.md                 # Quick start
    ├── MANIFEST.txt                      # Contents + checksums
    │
    ├── scripts/
    │   ├── 1-setup-registry.sh
    │   ├── 2-mirror-images.sh
    │   ├── 3-deploy-airgap.sh
    │   ├── 4-test-airgap.sh
    │   ├── run-all.sh
    │   ├── cleanup.sh
    │   ├── browse-registry.sh
    │   └── install-registry-ui.sh
    │
    ├── images/                           # ~2-3 GB uncompressed
    │   ├── gcr.io_knative-releases_..._operator_v1.15.0.tar
    │   ├── gcr.io_knative-releases_..._activator_v1.15.0.tar
    │   ├── ... (11 total image tar files)
    │   └── gcr.io_knative-samples_helloworld-go_latest.tar
    │
    ├── config/
    │   └── images.txt
    │
    ├── docs/
    │   ├── QUICK-START.md
    │   ├── DEPLOYMENT-GUIDE.md
    │   ├── TESTING-GUIDE.md
    │   ├── FAQ.md
    │   ├── TROUBLESHOOTING.md
    │   └── ... (9 documentation files)
    │
    └── examples/
        └── test-service.yaml
```

### File Sizes (Approximate)

- Total package (compressed): 2-3 GB
- Total package (uncompressed): 3-4 GB
- Images only: 2.5-3 GB
- Scripts + docs: 50-100 MB

---

**For the latest version and updates**, see the main [README.md](../README.md)
