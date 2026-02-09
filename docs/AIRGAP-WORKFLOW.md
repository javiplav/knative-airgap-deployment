# Airgap Deployment Workflow

Visual guide showing the complete end-to-end airgap deployment process.

## Complete Workflow Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           CONNECTED ENVIRONMENT                              │
│                         (System WITH Internet Access)                        │
└──────────────────────────────────────────────────────────────────────────────┘

    Step 1: Clone Repository
    ┌────────────────────────┐
    │ git clone repo         │
    │ cd knative-airgap      │
    └───────────┬────────────┘
                │
                ▼
    Step 2: Run Packaging Script
    ┌────────────────────────────────────────┐
    │ ./scripts/package-for-airgap.sh        │
    │                                        │
    │ Downloads:                             │
    │  • 11 Knative container images         │
    │  • Saves as tar files                  │
    │  • Packages with scripts & docs        │
    │  • Creates install.sh                  │
    │  • Generates checksums                 │
    └───────────┬────────────────────────────┘
                │
                ▼
    Output: knative-airgap-1.0.0.tar.gz (~2-3 GB)
    ┌────────────────────────────────────────┐
    │ build/knative-airgap-1.0.0.tar.gz      │
    │ build/knative-airgap-1.0.0.tar.gz.sha256│
    └───────────┬────────────────────────────┘
                │
                │
┌───────────────┴────────────────┐
│         TRANSFER ZONE          │
└────────────────────────────────┘
                │
    Step 3: Transfer Package
    ┌────────────────────────────────────────┐
    │ Transfer Method (choose one):          │
    │                                        │
    │ • USB Drive                            │
    │ • Secure File Transfer                 │
    │ • Physical Media (CD/DVD)              │
    │ • Approved Network Transfer            │
    │                                        │
    │ Include:                               │
    │  • tar.gz file                         │
    │  • sha256 checksum                     │
    └───────────┬────────────────────────────┘
                │
                │
┌───────────────┴────────────────────────────────────────────────────────────┐
│                         AIRGAPPED ENVIRONMENT                              │
│                       (System WITHOUT Internet Access)                     │
└────────────────────────────────────────────────────────────────────────────┘

    Step 4: Verify Package
    ┌────────────────────────────────────────┐
    │ sha256sum -c knative-airgap-*.sha256   │
    │                                        │
    │ Output: knative-airgap-*.tar.gz: OK    │
    └───────────┬────────────────────────────┘
                │
                ▼
    Step 5: Extract Package
    ┌────────────────────────────────────────┐
    │ tar -xzf knative-airgap-1.0.0.tar.gz   │
    │ cd knative-airgap-1.0.0/               │
    └───────────┬────────────────────────────┘
                │
                ▼
    Step 6: Run Installation
    ┌────────────────────────────────────────┐
    │ ./install.sh                           │
    │                                        │
    │ Automatically:                         │
    │  1. Loads images to Docker             │
    │  2. Deploys private registry           │
    │  3. Mirrors images to registry         │
    │  4. Deploys Knative Operator           │
    │  5. Deploys Knative Serving            │
    │  6. Tests installation                 │
    └───────────┬────────────────────────────┘
                │
                ▼
    Step 7: Verify Deployment
    ┌────────────────────────────────────────┐
    │ kubectl get pods -n knative-serving    │
    │ kubectl get pods -n registry           │
    │                                        │
    │ All pods: Running ✓                    │
    └───────────┬────────────────────────────┘
                │
                ▼
    Step 8: Access & Use
    ┌────────────────────────────────────────┐
    │ Registry UI: http://localhost:30600    │
    │ Registry API: http://localhost:30500   │
    │                                        │
    │ Deploy services:                       │
    │  kubectl apply -f examples/test-*.yaml │
    └────────────────────────────────────────┘

                ✓ COMPLETE ✓
```

## Detailed Step Breakdown

### Connected Environment Phase

#### Step 1: Clone Repository
```bash
git clone https://github.com/your-username/knative-airgap-deployment
cd knative-airgap
```

**Time**: 1-2 minutes
**Output**: Complete repository with all files

#### Step 2: Create Airgap Package
```bash
cd scripts
./package-for-airgap.sh
```

**What Happens**:
1. ✅ Checks Docker/nerdctl available
2. ✅ Creates build directory structure
3. ✅ Copies all scripts, docs, configs
4. ✅ Downloads 11 Knative images from gcr.io
5. ✅ Saves each image as .tar file
6. ✅ Generates install.sh script
7. ✅ Creates manifest with checksums
8. ✅ Compresses everything into .tar.gz

**Time**: 10-15 minutes (depends on internet speed)
**Output**:
- `build/knative-airgap-1.0.0.tar.gz` (~2-3 GB)
- `build/knative-airgap-1.0.0.tar.gz.sha256` (checksum)

**Disk Space Required**: ~5 GB temporary, ~3 GB final

### Transfer Phase

#### Step 3: Transfer Package

**USB Drive Method**:
```bash
# Copy to USB
cp build/knative-airgap-*.tar.gz /Volumes/USB/
cp build/knative-airgap-*.tar.gz.sha256 /Volumes/USB/

# Eject safely
diskutil eject /Volumes/USB
```

**Physical to Airgapped**:
1. Take USB to airgapped environment
2. Connect to airgapped system
3. Copy files from USB to local storage

**Important**:
- ✅ Transfer both .tar.gz and .sha256 files
- ✅ Use approved transfer method
- ✅ Maintain chain of custody if required
- ✅ Document transfer for audit

### Airgapped Environment Phase

#### Step 4: Verify Package Integrity
```bash
sha256sum -c knative-airgap-1.0.0.tar.gz.sha256
```

**Expected Output**:
```
knative-airgap-1.0.0.tar.gz: OK
```

**If Failed**: Do NOT proceed, package may be corrupted. Re-transfer.

#### Step 5: Extract Package
```bash
tar -xzf knative-airgap-1.0.0.tar.gz
cd knative-airgap-1.0.0/
ls -la
```

**Expected Contents**:
```
install.sh
README-PACKAGE.md
MANIFEST.txt
scripts/
images/
config/
docs/
examples/
```

#### Step 6: Prerequisites Check

Before running install.sh, verify:

```bash
# Kubernetes accessible?
kubectl cluster-info

# Nodes ready?
kubectl get nodes

# Docker running?
docker ps

# Sufficient resources?
kubectl top nodes
```

#### Step 7: Run Installation
```bash
./install.sh
```

**What Happens**:
1. ✅ Checks prerequisites (kubectl, docker, cluster)
2. ✅ Loads 11 images from tar files to Docker (~5 min)
3. ✅ Runs scripts/1-setup-registry.sh
4. ✅ Runs scripts/2-mirror-images.sh
5. ✅ Runs scripts/3-deploy-airgap.sh
6. ✅ Runs scripts/4-test-airgap.sh

**Time**: 10-15 minutes
**User Interaction**: Minimal (confirmation prompts only)

#### Step 8: Verification

```bash
# Check all namespaces
kubectl get pods --all-namespaces

# Specific checks
kubectl get pods -n registry
kubectl get pods -n knative-operator
kubectl get pods -n knative-serving

# Knative status
kubectl get knativeserving -n knative-serving
```

**Expected**: All pods in `Running` status

#### Step 9: Access Services

```bash
# Registry Web UI
open http://localhost:30600

# Or get URL programmatically
echo "Registry: http://localhost:$(kubectl get svc registry -n registry -o jsonpath='{.spec.ports[0].nodePort}')"
echo "Registry UI: http://localhost:$(kubectl get svc registry-ui -n registry -o jsonpath='{.spec.ports[0].nodePort}')"
```

## Time Estimates

| Phase | Step | Time | Notes |
|-------|------|------|-------|
| **Connected** | Clone repo | 1-2 min | One-time |
| | Create package | 10-15 min | Internet speed dependent |
| | **Subtotal** | **~15 min** | |
| **Transfer** | Copy to media | 5-10 min | Size dependent |
| | Physical transfer | Varies | Environment dependent |
| | **Subtotal** | **~15 min** | Excluding physical transport |
| **Airgapped** | Verify package | < 1 min | |
| | Extract | 1-2 min | |
| | Prerequisites | 2-5 min | If needed |
| | Installation | 10-15 min | |
| | **Subtotal** | **~15 min** | |
| **TOTAL** | **End-to-end** | **~45 min** | Excluding physical transport |

## Roles and Responsibilities

### Connected Environment Team
- Clone repository
- Run packaging script
- Verify package integrity
- Generate checksums
- Prepare for transfer

### Transfer/Security Team
- Receive package
- Verify approvals
- Execute transfer
- Maintain chain of custody
- Deliver to airgapped team

### Airgapped Environment Team
- Receive package
- Verify integrity
- Check prerequisites
- Run installation
- Validate deployment
- Document results

## Success Criteria

### Package Creation Success
- ✅ All 11 images downloaded
- ✅ Package created without errors
- ✅ Checksum generated
- ✅ Package size ~2-3 GB

### Transfer Success
- ✅ Checksum verified on destination
- ✅ Package extracted without errors
- ✅ All files present in manifest

### Installation Success
- ✅ All images loaded to Docker
- ✅ Registry pod running
- ✅ Operator pod running
- ✅ 6/6 Serving components running
- ✅ Test service deploys successfully

## Troubleshooting Quick Reference

### Package Creation Issues
- **Internet fails**: Resume script, it will skip existing images
- **Disk space**: Need ~5 GB total
- **Docker not running**: Start Docker first

### Transfer Issues
- **Checksum mismatch**: Re-transfer
- **Package too large**: Split with `split` command
- **USB not recognized**: Check format (use FAT32/exFAT)

### Installation Issues
- **Images won't load**: Check Docker running, disk space
- **kubectl fails**: Check cluster connection
- **Pods pending**: Check cluster resources
- **Registry fails**: Check port 30500 not in use

**Full troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## Security Considerations

### Package Integrity
- Always verify checksums before and after transfer
- Use cryptographic hashes (SHA-256)
- Maintain chain of custody

### Transfer Security
- Use approved transfer methods only
- Document all transfers
- Verify at each step
- Store packages securely

### Installation Security
- Run with least privilege necessary
- Review logs for anomalies
- Enable RBAC in Kubernetes
- Secure registry with TLS (production)

## Next Steps After Installation

1. **Configure TLS**: Add certificates for production
2. **Setup Authentication**: Enable registry auth
3. **Deploy Applications**: Start deploying your services
4. **Monitor**: Set up monitoring and logging
5. **Backup**: Create backup procedures
6. **Documentation**: Document your environment specifics

---

**For detailed instructions**, see [AIRGAP-PACKAGING.md](AIRGAP-PACKAGING.md)
