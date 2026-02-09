# Knative Airgap - Quick Start

## What You Have

✅ Complete airgap deployment testing kit for Knative
✅ All scripts ready to execute
✅ Prerequisites verified (Kubernetes, Helm, Docker)

## Run Everything Now

```bash
./run-all.sh
```

Takes ~15-20 minutes. Fully automated with prompts.

## Or Step-by-Step

```bash
./1-setup-harbor.sh          # 3-5 min: Setup Harbor registry
# → Create 'knative' project in Harbor UI (manual)
./2-mirror-images.sh         # 5-10 min: Mirror all images
./3-deploy-airgap.sh         # 3-5 min: Deploy Knative
./4-test-airgap.sh           # 1-2 min: Test deployment
```

## What It Does

```
1. Harbor Setup
   ├── Installs Harbor on Kubernetes
   ├── Exposes on NodePort
   └── Credentials: admin/Harbor12345

2. Image Mirroring
   ├── Pulls 11 Knative images from gcr.io
   ├── Re-tags for private registry
   └── Pushes to Harbor

3. Airgap Deployment
   ├── Modifies Knative manifests
   ├── Uses ONLY private registry
   └── Deploys Operator + Serving

4. Verification
   ├── Deploys test application
   ├── Verifies it works
   └── Confirms airgap success
```

## Files Created

**Scripts** (execution order):
- `0-cleanup.sh` - Remove everything
- `1-setup-harbor.sh` - Setup Harbor
- `2-mirror-images.sh` - Mirror images
- `3-deploy-airgap.sh` - Deploy Knative
- `4-test-airgap.sh` - Test deployment
- `run-all.sh` - Run all steps

**Docs**:
- `README-AIRGAP.md` - Complete guide (start here!)
- `AIRGAP-DEPLOYMENT-GUIDE.md` - Production deployment guide
- `QUICK-START.md` - This file
- `images.txt` - List of required images

**Auto-generated** (after running scripts):
- `harbor-config.env` - Connection details
- `image-mappings.txt` - Image mappings
- `operator-airgap.yaml` - Modified operator manifest
- `knative-serving-airgap.yaml` - Serving config

## Prerequisites ✅

All verified and ready:
- ✅ Kubernetes (Rancher Desktop)
- ✅ Helm 3.17.0
- ✅ Docker 27.4.0
- ✅ kubectl configured

## After Running

**View Harbor:**
```bash
source harbor-config.env
echo "Harbor UI: $HARBOR_UI"
echo "Username: admin"
echo "Password: Harbor12345"
```

**Check Knative:**
```bash
kubectl get pods -n knative-serving
kubectl get ksvc
```

**Access Services:**
```bash
kubectl port-forward -n knative-serving svc/kourier 8080:80
# Then: curl -H "Host: <service>.default.127.0.0.1.sslip.io" http://localhost:8080
```

## Cleanup

```bash
./0-cleanup.sh  # Removes everything
```

## Need Help?

1. **Read README-AIRGAP.md** - Comprehensive guide
2. **Check logs**: `kubectl logs -n <namespace> <pod>`
3. **View events**: `kubectl get events --sort-by='.lastTimestamp'`
4. **Troubleshooting section** in README-AIRGAP.md

## Production Deployment

After testing, see **AIRGAP-DEPLOYMENT-GUIDE.md** for:
- Production Harbor setup
- Image transfer procedures
- Security considerations
- Monitoring and operations

## Ready to Start?

```bash
./run-all.sh
```

Good luck! 🚀
