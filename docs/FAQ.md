# Frequently Asked Questions (FAQ)

## General Questions

### What is this project?

This project provides a complete, tested solution for deploying Knative Serving in airgapped environments (networks without internet access) using a private Docker registry.

### Why would I need this?

You need this if you're deploying Knative in:
- Airgapped/disconnected networks (high-security environments)
- Networks with restricted internet access
- On-premises installations without public registry access
- Environments with compliance requirements for image provenance

### Is this production-ready?

Yes, with caveats:
- ✅ The image mirroring and deployment process is production-ready
- ✅ Core Knative components (6/6) work perfectly
- ⚠️ Kourier gateway (Envoy) needs additional configuration
- 💡 For production, consider using Harbor on Linux and Istio/Contour for ingress

## Installation Questions

### What are the prerequisites?

- Kubernetes cluster (any distribution)
- kubectl configured
- Helm 3.x
- Docker or container runtime
- ~3GB disk space
- Internet access (for initial image mirroring)

### How long does setup take?

- **Automated (run-all.sh)**: 10-15 minutes
- **Manual step-by-step**: 15-20 minutes
- Most time is spent downloading and mirroring images

### Can I use this on [my Kubernetes distribution]?

Yes! This works on:
- ✅ Rancher Desktop (tested)
- ✅ kind
- ✅ k3s (on Linux)
- ✅ minikube
- ✅ EKS, GKE, AKS
- ✅ On-premises Kubernetes

**Note**: k3s doesn't run natively on macOS. Use Rancher Desktop on macOS.

### Why doesn't k3s work on macOS?

k3s requires systemd/openrc which macOS doesn't have. Use Rancher Desktop (which runs k3s in a VM) or kind instead.

## Registry Questions

### Why Docker Registry v2 instead of Harbor?

Harbor had compatibility issues on macOS ARM architecture. Docker Registry v2:
- ✅ Works on all platforms
- ✅ Lightweight and fast
- ✅ Sufficient for most airgap needs

For production on Linux, Harbor is recommended for its additional features.

### Can I use my existing registry?

Yes! Modify the scripts to point to your registry:
1. Update `REGISTRY_URL` in `1-setup-registry.sh` (or skip this script)
2. Run `2-mirror-images.sh` with your registry URL
3. Continue with deployment scripts

### How do I browse the registry?

Three options:
1. **Web UI**: http://localhost:30600 (after running `install-registry-ui.sh`)
2. **CLI Script**: `./scripts/browse-registry.sh`
3. **API**: `curl http://localhost:30500/v2/_catalog`

### Where are the images stored?

In a Kubernetes PersistentVolume mounted at `/var/lib/registry` in the registry pod.

Check storage:
```bash
kubectl get pvc -n registry
kubectl exec -n registry deployment/registry -- du -sh /var/lib/registry
```

## Image Questions

### Why do images show creation date "a year ago"?

This is **correct**! The creation date reflects when Knative originally built the images (May 2024 for v1.15.0), not when you mirrored them.

This is actually good:
- ✅ Proves images are authentic
- ✅ Shows they haven't been modified
- ✅ Expected behavior for mirrored images

See [IMAGE-DATES-EXPLAINED.md](IMAGE-DATES-EXPLAINED.md) for details.

### Are these images outdated?

No, they're the official Knative v1.15.0 release. If you need newer versions:
- Use v1.16+ if available
- Update `config/images.txt` with new versions
- Re-run the mirroring script

### How do I verify images are from my private registry?

```bash
# Check pod image
kubectl get pods -n knative-serving -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n'

# All should show: localhost:30500/...
```

See [PROOF-OF-AIRGAP.md](PROOF-OF-AIRGAP.md) for complete verification.

### Can I add more images?

Yes! Edit `config/images.txt` and add your images, then run:
```bash
./scripts/2-mirror-images.sh
```

## Deployment Questions

### How does Knative know to use private registry?

We configure the `KnativeServing` Custom Resource with `registry.override` settings. The Knative Operator reads this and creates deployments with your registry images.

See [IMAGE-OVERRIDE-EXPLAINED.md](IMAGE-OVERRIDE-EXPLAINED.md) for the complete mechanism.

### What if deployment fails?

1. Check operator logs:
   ```bash
   kubectl logs -n knative-operator -l app=operator
   ```

2. Check Knative status:
   ```bash
   kubectl get knativeserving -n knative-serving
   kubectl describe knativeserving knative-serving -n knative-serving
   ```

3. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

### Why is Kourier gateway not working?

The Kourier gateway uses Envoy proxy which requires special configuration. This is a known issue with the current approach.

**Solutions**:
1. Add Envoy image to mirroring and configure properly
2. Use alternative ingress (Istio or Contour - better for airgap)
3. See troubleshooting guide for detailed fixes

### Can I use this without the registry UI?

Yes! The web UI is optional. You can use:
- `./scripts/browse-registry.sh` for CLI browsing
- Direct API: `curl http://localhost:30500/v2/_catalog`
- Docker CLI: `docker pull localhost:30500/...`

## Testing Questions

### How do I test the deployment?

Run the test script:
```bash
./scripts/4-test-airgap.sh
```

Or manually:
```bash
kubectl get pods -n knative-serving
kubectl get ksvc
```

### How do I deploy a test service?

```bash
kubectl apply -f examples/test-service.yaml
```

Or use the one from the test script.

### How do I access services?

Since we're running locally, use port-forwarding:
```bash
kubectl port-forward -n knative-serving svc/kourier 8080:80
```

Then access services through localhost:8080 with the appropriate Host header.

## Production Questions

### What should I change for production?

1. **Use Harbor on Linux** (better features, security scanning)
2. **Enable TLS** on registry
3. **Add authentication** to registry
4. **Use Istio/Contour** instead of Kourier
5. **Pin all versions** (never use :latest)
6. **Set up monitoring** for registry and Knative
7. **Create backup procedures** for registry data
8. **Document your image update process**

### How do I update to newer Knative versions?

1. Update image versions in `config/images.txt`
2. Run `./scripts/2-mirror-images.sh`
3. Update `version` in KnativeServing manifest
4. Update `registry.override` image tags
5. Apply the updated manifest

### How do I handle image updates?

For security updates:
1. Pull new images from public registry (on connected system)
2. Mirror to private registry
3. Update KnativeServing manifest with new tags
4. Restart affected deployments

### What about security scanning?

- **Current setup**: No built-in scanning
- **Recommendation**: Use Harbor with Trivy integration
- **Alternative**: Scan images before mirroring using external tools

### How do I backup the registry?

```bash
# Backup all images as tar files
mkdir -p registry-backup
for image in $(curl -s http://localhost:30500/v2/_catalog | jq -r '.repositories[]'); do
  docker pull localhost:30500/$image:latest
  docker save localhost:30500/$image:latest -o registry-backup/$image.tar
done
```

## Cleanup Questions

### How do I remove everything?

```bash
./scripts/cleanup.sh
```

This removes:
- Knative Serving
- Knative Operator
- Docker Registry
- All test services

### Will cleanup delete my images?

Yes, it deletes the PersistentVolume. If you want to keep images, backup first (see above).

### How do I start fresh?

```bash
./scripts/cleanup.sh
./scripts/run-all.sh
```

## Troubleshooting Questions

### Registry pod won't start

Check:
```bash
kubectl get pods -n registry
kubectl logs -n registry deployment/registry
kubectl describe pod -n registry <pod-name>
```

Common causes:
- Insufficient resources (increase RAM/CPU)
- PVC issues (check storage class)

### Images won't pull

Check registry is accessible:
```bash
curl http://localhost:30500/v2/_catalog
docker pull localhost:30500/knative-activator:v1.15.0
```

### Knative pods stuck in ImagePullBackOff

1. Check image name in deployment matches registry
2. Verify image exists: `curl http://localhost:30500/v2/<image>/tags/list`
3. Check operator logs for errors

### Web UI shows "0 images"

1. Check CORS is enabled on registry
2. Verify registry URL in UI config
3. Hard refresh browser (Cmd/Ctrl + Shift + R)

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions.

## Performance Questions

### How much disk space do I need?

- **Images**: ~2-3 GB for all Knative images
- **Registry overhead**: ~500 MB
- **Recommended**: 5-10 GB free space

### How much RAM/CPU?

**Minimum**:
- 4 GB RAM
- 2 CPU cores

**Recommended**:
- 6-8 GB RAM
- 4 CPU cores

Adjust in Rancher Desktop: Preferences → Resources

### Can I reduce resource usage?

Yes:
- Use fewer Knative components (disable what you don't need)
- Use external registry (don't run registry in cluster)
- Disable registry UI if not needed

## Advanced Questions

### Can I use multiple registries?

Yes, configure different registries for different components in `registry.override`.

### Can I mirror to multiple registries?

Yes, modify the mirroring script to push to multiple registries.

### How do I use image pull secrets?

If your registry requires authentication:
```bash
kubectl create secret docker-registry registry-creds \
  --docker-server=localhost:30500 \
  --docker-username=admin \
  --docker-password=password

# Add to KnativeServing spec
spec:
  workloads:
  - name: activator
    imagePullSecrets:
    - name: registry-creds
```

### Can I customize the Knative configuration?

Yes! Edit the generated `knative-serving-airgap.yaml` before applying, or patch after:
```bash
kubectl edit knativeserving knative-serving -n knative-serving
```

## Getting Help

### Where can I find more information?

- **This repo**: Check the [docs/](.) directory
- **Knative Docs**: https://knative.dev/docs/
- **Docker Registry**: https://docs.docker.com/registry/

### How do I report issues?

Open an issue on GitHub with:
- Your environment (Kubernetes version, platform)
- Steps to reproduce
- Error messages/logs
- What you've tried

### Can I contribute?

Yes! Pull requests are welcome. Please:
- Test your changes
- Update documentation
- Follow existing code style

---

**Still have questions?** Open an issue on GitHub or check the [TROUBLESHOOTING.md](TROUBLESHOOTING.md) guide.
