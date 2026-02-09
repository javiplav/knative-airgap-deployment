# How Knative Image Override Works (Complete Explanation)

## Overview

The key to making Knative use your private registry is the **KnativeServing Custom Resource** and its `registry.override` configuration. Here's how it all works.

## The Complete Flow

```
┌──────────────────────────────────────────────────────────────────┐
│  1. You Apply KnativeServing CR with registry overrides         │
│     kubectl apply -f knative-serving-airgap.yaml                 │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  2. Knative Operator watches for KnativeServing resources       │
│     The operator pod runs in knative-operator namespace          │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  3. Operator reads the registry.override configuration           │
│     - Sees: activator → localhost:30500/knative-activator:v1.15.0│
│     - Sees: controller → localhost:30500/knative-controller:v1.15.0│
│     - Etc. for all components                                    │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  4. Operator generates Kubernetes Deployments                    │
│     Instead of default gcr.io images, uses your overrides        │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  5. Kubernetes pulls images from localhost:30500                 │
│     All Knative pods now use your private registry!              │
└──────────────────────────────────────────────────────────────────┘
```

## The Key Configuration

### What We Applied

```yaml
apiVersion: operator.knative.dev/v1beta1
kind: KnativeServing
metadata:
  name: knative-serving
  namespace: knative-serving
spec:
  version: "1.15.0"

  # THIS IS THE MAGIC! 🎯
  registry:
    default: localhost:30500           # Default registry for components
    override:
      activator: localhost:30500/knative-activator:v1.15.0
      autoscaler: localhost:30500/knative-autoscaler:v1.15.0
      controller: localhost:30500/knative-controller:v1.15.0
      webhook: localhost:30500/knative-webhook:v1.15.0
      queue-proxy: localhost:30500/knative-queue:v1.15.0
      net-kourier-controller/controller: localhost:30500/knative-kourier:v1.15.0
```

### What Each Part Does

| Field | Purpose | Example |
|-------|---------|---------|
| `registry.default` | Base registry URL used if no specific override | `localhost:30500` |
| `registry.override.<component>` | Full image path for specific component | `localhost:30500/knative-activator:v1.15.0` |
| `config.deployment.registriesSkippingTagResolving` | Skip tag resolution for private registries | `localhost:30500` |

## The Operator's Role

### Without Override (Default Behavior)

```yaml
# Operator would create this:
apiVersion: apps/v1
kind: Deployment
metadata:
  name: activator
spec:
  template:
    spec:
      containers:
      - name: activator
        image: gcr.io/knative-releases/knative.dev/serving/cmd/activator@sha256:b6d7d96...
```

### With Override (Our Configuration)

```yaml
# Operator creates this instead:
apiVersion: apps/v1
kind: Deployment
metadata:
  name: activator
spec:
  template:
    spec:
      containers:
      - name: activator
        image: localhost:30500/knative-activator:v1.15.0  # ✅ Your private registry!
```

## How to Verify It's Working

### 1. Check the KnativeServing Resource

```bash
kubectl get knativeserving knative-serving -n knative-serving -o yaml | grep -A 10 "registry:"
```

Output shows:
```yaml
registry:
  default: localhost:30500
  override:
    activator: localhost:30500/knative-activator:v1.15.0
    # ... more components
```

### 2. Check Actual Deployments

```bash
kubectl get deployment activator -n knative-serving -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Output:
```
localhost:30500/knative-activator:v1.15.0
```

✅ **Match!** The deployment uses the override we specified.

### 3. Check Running Pods

```bash
kubectl get pods activator-698bff7477-s78rw -n knative-serving -o jsonpath='{.spec.containers[0].image}'
```

Output:
```
localhost:30500/knative-activator:v1.15.0
```

✅ **Match!** The pod is using the private registry.

### 4. Check Image Pull Events

```bash
kubectl get events -n knative-serving --sort-by='.lastTimestamp' | grep "pull" | grep activator
```

Output:
```
Container image "localhost:30500/knative-activator:v1.15.0" already present on machine
```

✅ **Proof!** Kubernetes pulled from localhost:30500.

## Component Mapping

Here's how each Knative component maps to our private registry:

| Original Image (Public) | Override (Private) | Component Purpose |
|------------------------|-------------------|-------------------|
| gcr.io/.../activator:v1.15.0 | localhost:30500/knative-activator:v1.15.0 | Request activation |
| gcr.io/.../autoscaler:v1.15.0 | localhost:30500/knative-autoscaler:v1.15.0 | Auto-scaling pods |
| gcr.io/.../controller:v1.15.0 | localhost:30500/knative-controller:v1.15.0 | Control plane |
| gcr.io/.../webhook:v1.15.0 | localhost:30500/knative-webhook:v1.15.0 | Admission webhooks |
| gcr.io/.../queue:v1.15.0 | localhost:30500/knative-queue:v1.15.0 | Queue proxy sidecar |
| gcr.io/.../kourier:v1.15.0 | localhost:30500/knative-kourier:v1.15.0 | Ingress controller |

## The Operator Mechanism

### How the Operator Works

1. **Watches**: Operator continuously watches KnativeServing resources
2. **Reads**: When it sees registry.override, it reads those values
3. **Generates**: Creates/updates Deployments with overridden images
4. **Reconciles**: If you change the KnativeServing, operator updates Deployments

### Operator Pod

```bash
kubectl get pods -n knative-operator -l app=operator
```

Output:
```
knative-operator-6b97d8f457-zr5sp   1/1   Running
```

This pod contains the logic that translates your KnativeServing config into actual Kubernetes resources.

### Operator Logs

```bash
kubectl logs -n knative-operator -l app=operator | grep -i "registry"
```

You can see the operator processing registry configurations.

## Alternative Methods (Not Used Here)

### Method 1: Modify Operator Manifest Directly

You can modify the operator deployment itself:

```bash
# We did this for the Knative Operator
cat operator-original.yaml | \
  sed 's|gcr.io/knative-releases/knative.dev/operator/cmd/operator:v1.15.0|localhost:30500/knative-operator:v1.15.0|g' \
  > operator-airgap.yaml

kubectl apply -f operator-airgap.yaml
```

This changes the operator's own image, not the images it deploys.

### Method 2: Image Pull Secrets (Not Needed for HTTP)

If your registry required authentication:

```bash
kubectl create secret docker-registry registry-creds \
  --docker-server=localhost:30500 \
  --docker-username=admin \
  --docker-password=password

# Then reference in KnativeServing
spec:
  workloads:
  - name: activator
    imagePullSecrets:
    - name: registry-creds
```

### Method 3: Admission Webhook (Complex)

Use a mutating admission webhook to rewrite all image references. Too complex for most use cases.

## Why This Approach Works Best

✅ **Declarative**: Single YAML defines everything
✅ **Operator-Managed**: Operator handles all the deployment details
✅ **Centralized**: One place to configure all images
✅ **Upgradable**: Easy to update by modifying KnativeServing
✅ **Knative-Native**: Uses Knative's built-in registry override feature

## Script That Generated This

From `3-deploy-airgap-simple.sh`:

```bash
# Extract image mappings
ACTIVATOR_IMG=$(grep "serving/cmd/activator" image-mappings.txt | cut -d'=' -f2)
AUTOSCALER_IMG=$(grep "serving/cmd/autoscaler:v" image-mappings.txt | cut -d'=' -f2)
# ... more extractions

# Create KnativeServing with overrides
cat > knative-serving-airgap.yaml <<EOF
apiVersion: operator.knative.dev/v1beta1
kind: KnativeServing
metadata:
  name: knative-serving
  namespace: knative-serving
spec:
  version: "1.15.0"
  registry:
    default: $REGISTRY_URL
    override:
      activator: $ACTIVATOR_IMG
      autoscaler: $AUTOSCALER_IMG
      # ... more overrides
EOF

kubectl apply -f knative-serving-airgap.yaml
```

## Important Notes

### registriesSkippingTagResolving

```yaml
config:
  deployment:
    registriesSkippingTagResolving: "localhost:30500"
```

This tells Knative **not** to resolve tags to digests for your private registry. Important because:
- Some registries don't support digest resolution
- Speeds up deployment
- Works better with non-standard registries

### Queue Proxy Sidecar

The `queue-proxy` override is special:

```yaml
queue-proxy: localhost:30500/knative-queue:v1.15.0
```

This image is injected as a sidecar into **every user workload** by Knative. Without this override, user pods would try to pull from the public registry!

### Net Kourier Controller

The path uses a slash:

```yaml
net-kourier-controller/controller: localhost:30500/knative-kourier:v1.15.0
```

This is the Knative naming convention for sub-components. The operator knows how to handle this.

## Testing Image Override

### Create a Test Service

```bash
cat <<EOF | kubectl apply -f -
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: test
spec:
  template:
    spec:
      containers:
      - image: localhost:30500/knative-helloworld-go:latest
EOF
```

### Check the Queue Proxy

```bash
kubectl get pod -l serving.knative.dev/service=test -o jsonpath='{.items[0].spec.containers[*].image}' | tr ' ' '\n'
```

You'll see:
```
localhost:30500/knative-helloworld-go:latest  # Your app
localhost:30500/knative-queue:v1.15.0         # Queue proxy from override!
```

✅ Both images come from your private registry!

## Troubleshooting

### Override Not Applied

**Check**: Does the KnativeServing resource have the override?
```bash
kubectl get knativeserving knative-serving -n knative-serving -o yaml | grep override
```

**Fix**: Reapply the KnativeServing manifest
```bash
kubectl apply -f knative-serving-airgap.yaml
```

### Wrong Image in Deployment

**Check**: What does the deployment spec say?
```bash
kubectl get deployment activator -n knative-serving -o yaml | grep image:
```

**Fix**: Operator might not have reconciled yet
```bash
kubectl rollout restart deployment knative-operator -n knative-operator
```

### Image Pull Fails

**Check**: Can the node access the registry?
```bash
kubectl run test --image=localhost:30500/knative-activator:v1.15.0 --restart=Never
kubectl logs test
```

**Fix**: Ensure registry is accessible from all cluster nodes

## Summary

The image override works through this simple but powerful mechanism:

1. **You declare** image overrides in KnativeServing CR
2. **Operator reads** those overrides
3. **Operator creates** Deployments with overridden images
4. **Kubernetes pulls** from your private registry
5. **Everything works** in airgap mode!

The beauty is that it's **declarative** - you just tell Knative what images to use, and the operator handles all the complex deployment details.

---

**Files to reference:**
- `knative-serving-airgap.yaml` - The KnativeServing configuration
- `3-deploy-airgap-simple.sh` - Script that generates and applies it
- `image-mappings.txt` - Mapping of public→private images
