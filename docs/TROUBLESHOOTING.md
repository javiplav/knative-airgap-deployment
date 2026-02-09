# Troubleshooting Guide

This guide covers common issues and their solutions.

## Table of Contents

- [Registry Issues](#registry-issues)
- [Image Mirroring Issues](#image-mirroring-issues)
- [Knative Operator Issues](#knative-operator-issues)
- [Knative Serving Issues](#knative-serving-issues)
- [Networking Issues](#networking-issues)
- [Performance Issues](#performance-issues)
- [Web UI Issues](#web-ui-issues)

## Registry Issues

### Registry Pod Won't Start

**Symptoms**: Registry pod in CrashLoopBackOff or Pending

**Check**:
```bash
kubectl get pods -n registry
kubectl describe pod -n registry <pod-name>
kubectl logs -n registry <pod-name>
```

**Common Causes**:

1. **Insufficient Resources**
   ```bash
   # Check resources
   kubectl describe pod -n registry <pod-name> | grep -A 5 "Resources"
   ```
   **Solution**: Increase Rancher Desktop resources (Preferences → Resources)

2. **PVC Issues**
   ```bash
   kubectl get pvc -n registry
   kubectl describe pvc registry-pvc -n registry
   ```
   **Solution**: Ensure your cluster has a working storage class

3. **Port Conflict**
   **Solution**: Check if port 30500 is already in use
   ```bash
   lsof -i :30500
   ```

### Registry Not Accessible

**Symptoms**: `curl http://localhost:30500/v2/` fails

**Check**:
```bash
# Is registry running?
kubectl get pods -n registry

# Is service configured?
kubectl get svc registry -n registry

# Check NodePort
kubectl get svc registry -n registry -o jsonpath='{.spec.ports[0].nodePort}'
```

**Solutions**:

1. **Port-forward if NodePort not working**:
   ```bash
   kubectl port-forward -n registry svc/registry 30500:5000
   ```

2. **Check firewall**: Ensure localhost:30500 is not blocked

3. **Restart registry**:
   ```bash
   kubectl rollout restart deployment registry -n registry
   ```

### Registry Running Out of Space

**Check**:
```bash
kubectl exec -n registry deployment/registry -- df -h /var/lib/registry
```

**Solution**:
```bash
# Increase PVC size (requires storage class support)
kubectl edit pvc registry-pvc -n registry

# Or delete unused images
./scripts/browse-registry.sh
# Then use Docker to remove images
```

## Image Mirroring Issues

### Image Pull Fails During Mirroring

**Symptoms**: "error pulling image" during `2-mirror-images.sh`

**Check**:
```bash
# Test direct pull
docker pull gcr.io/knative-releases/knative.dev/serving/cmd/activator:v1.15.0

# Check internet connection
ping google.com
```

**Solutions**:

1. **Proxy Issues**: Configure Docker proxy if behind corporate proxy
   ```bash
   # Edit ~/.docker/config.json
   ```

2. **Rate Limiting**: Wait and retry, or use authentication

3. **Network Issues**: Check firewall/VPN settings

### Image Push Fails

**Symptoms**: "error pushing image" to localhost:30500

**Check**:
```bash
# Is registry accessible?
curl http://localhost:30500/v2/

# Test login (if auth required)
docker login localhost:30500
```

**Solutions**:

1. **Registry Not Running**: Start registry first
   ```bash
   kubectl get pods -n registry
   ```

2. **Insufficient Space**: Check registry storage

3. **CORS Issues**: Ensure registry config has CORS headers (should be set by scripts)

### Partial Image Mirror

**Symptoms**: Some images succeeded, others failed

**Solution**:
```bash
# Re-run mirroring script - it will skip existing images
./scripts/2-mirror-images.sh

# Or mirror specific images manually
docker pull gcr.io/knative-releases/knative.dev/serving/cmd/activator:v1.15.0
docker tag gcr.io/knative-releases/knative.dev/serving/cmd/activator:v1.15.0 \
  localhost:30500/knative-activator:v1.15.0
docker push localhost:30500/knative-activator:v1.15.0
```

## Knative Operator Issues

### Operator Pod Won't Start

**Check**:
```bash
kubectl get pods -n knative-operator
kubectl describe pod -n knative-operator <pod-name>
kubectl logs -n knative-operator <pod-name>
```

**Common Issues**:

1. **Image Pull Failed**
   - Verify image is in registry: `curl http://localhost:30500/v2/knative-operator/tags/list`
   - Check image name in deployment matches

2. **Wrong Image Reference**
   ```bash
   kubectl get deployment knative-operator -n knative-operator -o yaml | grep image:
   ```
   Should show: `localhost:30500/knative-operator:v1.15.0`

**Solution**:
```bash
# Reapply operator manifest
kubectl apply -f operator-airgap.yaml
```

### Operator Not Creating Knative Serving

**Check**:
```bash
# Check operator logs
kubectl logs -n knative-operator -l app=operator --tail=50

# Check if KnativeServing was applied
kubectl get knativeserving -n knative-serving
```

**Solutions**:

1. **Reapply KnativeServing**:
   ```bash
   kubectl apply -f knative-serving-airgap.yaml
   ```

2. **Check for errors in operator logs**:
   ```bash
   kubectl logs -n knative-operator -l app=operator | grep -i error
   ```

3. **Restart operator**:
   ```bash
   kubectl rollout restart deployment knative-operator -n knative-operator
   ```

## Knative Serving Issues

### Pods Stuck in ImagePullBackOff

**Symptoms**: Knative Serving pods can't pull images

**Check**:
```bash
kubectl get pods -n knative-serving
kubectl describe pod -n knative-serving <pod-name>
```

**Common Causes**:

1. **Wrong Image Name**
   ```bash
   # Check what image is configured
   kubectl get deployment activator -n knative-serving -o jsonpath='{.spec.template.spec.containers[0].image}'

   # Should be: localhost:30500/knative-activator:v1.15.0
   ```

2. **Image Not in Registry**
   ```bash
   curl http://localhost:30500/v2/knative-activator/tags/list
   ```

3. **Registry Not Accessible from Nodes**
   ```bash
   # Test from a debug pod
   kubectl run test --image=curlimages/curl --restart=Never -- curl http://registry.registry.svc.cluster.local:5000/v2/
   ```

**Solutions**:

1. **Fix KnativeServing Config**:
   ```bash
   kubectl edit knativeserving knative-serving -n knative-serving
   # Update registry.override values
   ```

2. **Verify Image Mapping**:
   ```bash
   cat image-mappings.txt
   ```

3. **Re-mirror Missing Image**:
   ```bash
   ./scripts/2-mirror-images.sh
   ```

### Knative Serving Not Ready

**Check**:
```bash
kubectl get knativeserving knative-serving -n knative-serving
kubectl describe knativeserving knative-serving -n knative-serving
```

**Common Messages**:

1. **"Waiting on deployments: XYZ"**
   - Check the specific deployment: `kubectl get deployment XYZ -n knative-serving`
   - Check pods: `kubectl get pods -n knative-serving | grep XYZ`
   - Check logs: `kubectl logs -n knative-serving deployment/XYZ`

2. **"DependenciesInstalled: False"**
   - Check CRDs: `kubectl get crd | grep knative`
   - Reinstall operator if needed

### Kourier Gateway Issues

**Symptoms**: 3scale-kourier-gateway pod failing

**Known Issue**: Envoy image requires special configuration

**Solutions**:

**Option 1 - Use Included Envoy** (requires internet):
```bash
kubectl patch knativeserving knative-serving -n knative-serving --type=json -p='[
  {"op": "add", "path": "/spec/registry/override/3scale-kourier-gateway",
   "value": "docker.io/envoyproxy/envoy:distroless-v1.29.7"}
]'
```

**Option 2 - Mirror Envoy**:
1. Add to `config/images.txt`:
   ```
   docker.io/envoyproxy/envoy:distroless-v1.29.7
   ```
2. Mirror: `./scripts/2-mirror-images.sh`
3. Update KnativeServing

**Option 3 - Use Different Ingress** (Recommended):
Use Istio or Contour instead of Kourier (better for airgap)

## Networking Issues

### Can't Access Knative Services

**Check**:
```bash
# Is service ready?
kubectl get ksvc

# Are pods running?
kubectl get pods | grep <service-name>

# Check Kourier
kubectl get pods -n knative-serving | grep kourier
```

**Solutions**:

1. **Port-Forward to Access**:
   ```bash
   kubectl port-forward -n knative-serving svc/kourier 8080:80

   # Then access with Host header
   curl -H "Host: <service>.default.127.0.0.1.sslip.io" http://localhost:8080
   ```

2. **Check Service URL**:
   ```bash
   kubectl get ksvc <service-name> -o jsonpath='{.status.url}'
   ```

3. **Check Service Ready**:
   ```bash
   kubectl get ksvc <service-name> -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'
   ```

### DNS Issues

**Symptoms**: Services can't resolve each other

**Check**:
```bash
# Check CoreDNS
kubectl get pods -n kube-system | grep coredns

# Test DNS
kubectl run test --image=busybox --restart=Never -- nslookup kubernetes.default
```

**Solution**: Usually cluster-specific, check cluster DNS configuration

## Performance Issues

### Slow Image Pulls

**Cause**: Large images or slow network

**Solutions**:
1. Be patient - first pull is always slower
2. Use faster internet connection for mirroring
3. Mirror images to closer/faster registry

### Registry Running Slow

**Check**:
```bash
# Check resource usage
kubectl top pod -n registry
```

**Solutions**:
1. Increase registry resources
2. Use external registry with better hardware
3. Enable caching in registry config

### Pods Crashing Due to OOM

**Check**:
```bash
kubectl describe pod -n knative-serving <pod-name> | grep -i oom
```

**Solution**: Increase cluster resources (RAM)

## Web UI Issues

### UI Shows "0 images"

**Causes**: CORS or connection issues

**Check**:
```bash
# Test CORS
curl -I http://localhost:30500/v2/

# Should see: Access-Control-Allow-Origin: *
```

**Solutions**:

1. **Hard Refresh Browser**: Cmd/Ctrl + Shift + R

2. **Check UI Config**:
   ```bash
   kubectl get deployment registry-ui -n registry -o jsonpath='{.spec.template.spec.containers[0].env}'
   ```
   Should show: `REGISTRY_URL: http://localhost:30500`

3. **Reinstall UI**:
   ```bash
   kubectl delete deployment registry-ui -n registry
   ./scripts/install-registry-ui.sh
   ```

### UI Won't Load

**Check**:
```bash
kubectl get pods -n registry | grep registry-ui
kubectl logs -n registry deployment/registry-ui
```

**Solutions**:

1. **Port Conflict**: Check if 30600 is in use
   ```bash
   lsof -i :30600
   ```

2. **Restart UI**:
   ```bash
   kubectl rollout restart deployment registry-ui -n registry
   ```

## Script Issues

### Script Fails with "command not found"

**Missing Dependencies**:

```bash
# Check requirements
kubectl version
helm version
docker version  # or nerdctl version
jq --version
```

**Solution**: Install missing tools

### Script Hangs

**Common Causes**:
1. Waiting for user input - check terminal
2. Timeout waiting for pods - check cluster resources
3. Network issues - check connectivity

**Solution**: Use `Ctrl+C` to cancel, check logs, run step-by-step instead

## Advanced Debugging

### Enable Verbose Logging

**Operator**:
```bash
kubectl set env deployment knative-operator -n knative-operator SYSTEM_NAMESPACE=knative-operator LOG_LEVEL=debug
```

**Registry**:
```bash
# Check registry logs
kubectl logs -n registry deployment/registry --tail=100 -f
```

### Check All Component Status

```bash
# Quick health check
echo "Registry:" && kubectl get pods -n registry && \
echo "Operator:" && kubectl get pods -n knative-operator && \
echo "Serving:" && kubectl get pods -n knative-serving && \
echo "Services:" && kubectl get ksvc --all-namespaces
```

### Dump All Resources

```bash
# For bug reports
kubectl get all -n registry > debug-registry.txt
kubectl get all -n knative-operator > debug-operator.txt
kubectl get all -n knative-serving > debug-serving.txt
kubectl get knativeserving -n knative-serving -o yaml > debug-knativeserving.yaml
```

## Getting Help

If you're still stuck:

1. **Check the FAQ**: [FAQ.md](FAQ.md)
2. **Review Documentation**: All docs in [docs/](.)
3. **Check Logs**: Operator and component logs often show the issue
4. **Open an Issue**: On GitHub with:
   - Your environment details
   - Steps to reproduce
   - Error messages
   - What you've tried
   - Output from debug commands

## Prevention Tips

1. **Test in Stages**: Run scripts one at a time to catch issues early
2. **Check Resources**: Ensure adequate RAM/CPU before starting
3. **Verify Prerequisites**: Make sure all tools are installed
4. **Monitor During Setup**: Watch logs during deployment
5. **Keep Backups**: Backup registry data periodically
6. **Document Changes**: Note any customizations you make

---

**Still having issues?** Open a GitHub issue with your debug output!
