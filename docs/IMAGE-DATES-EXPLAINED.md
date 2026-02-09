# Why Image Creation Dates Show "A Year Ago"

## Quick Answer

✅ **This is CORRECT and EXPECTED behavior!**

The "a year ago" date you see refers to when the image was **originally built by the Knative project**, not when you mirrored it to your private registry.

## Understanding Container Image Dates

### What Gets Preserved When Mirroring

When you pull and push a container image to a new registry, the following are preserved:

1. ✅ **All image layers** (exact binary data)
2. ✅ **Image metadata** (including creation timestamp)
3. ✅ **Image digest/hash** (cryptographic signature)
4. ✅ **Build information** (labels, environment variables, etc.)

**The creation date is part of the immutable image metadata.**

### Why This Matters for Airgap Deployments

This is actually **good news** for your airgap scenario:

✅ **Authenticity**: The preserved creation date proves the images are genuine and unmodified
✅ **Traceability**: You can verify these are the official Knative v1.15.0 images
✅ **Integrity**: The image hasn't been rebuilt or tampered with

## Knative v1.15.0 Timeline

| Event | Date | Time from Now (Feb 2026) |
|-------|------|-------------------------|
| Knative v1.15.0 Released | May 2024 | ~19 months ago |
| Images Built | May 2024 | ~19 months ago |
| You Mirrored Images | Today (Feb 2026) | Today |

**The UI shows "a year ago" which is approximately correct for v1.15.0**

## What Dates Mean

### Image Creation Date (What you see: "a year ago")
- When the Knative team built the image
- Embedded in the image manifest
- **Cannot and should not be changed**
- Shows: May 2024 (for v1.15.0)

### Registry Push Date (Not shown in this UI)
- When you pushed to localhost:30500
- Registry metadata, not image metadata
- Shows: Today (Feb 2026)

## How to Verify Image Authenticity

### Check the Content Digest

The content digest is a cryptographic hash that proves the image hasn't been modified:

```bash
# Your mirrored image
curl -I http://localhost:30500/v2/knative-activator/manifests/v1.15.0 | grep Docker-Content-Digest

# Should match the official image digest
# Example: sha256:22dc0dc2f1fe6ce7b6b8019ed61469f4c3900ae0481a13d94e318ef556e5c98d
```

If the digests match between your registry and the official registry, the images are **byte-for-byte identical**, despite being in different registries.

## Real-World Example

Think of it like copying a document:

1. **Original Document**: Written on May 15, 2024
2. **You Copy It**: February 9, 2026
3. **Document Date Shown**: May 15, 2024 (the creation date)

The document still shows its original creation date even though you just copied it today. Same with container images!

## What If You Want Current Dates?

If you need more recent images, you would need to:

1. **Use a newer Knative version** (e.g., v1.16, v1.17 if available)
2. **Rebuild from source** (not recommended - lose official signatures)

But for airgap deployments, you **want** these exact official images with their original timestamps.

## Verification Commands

### Check image creation date from manifest

```bash
# Get full image manifest
curl -s http://localhost:30500/v2/knative-activator/manifests/v1.15.0 | jq .

# The creation timestamp is in the image config layers
```

### List all images with their info

```bash
# Using the browse script
./browse-registry.sh all

# Or directly via API
for img in $(curl -s http://localhost:30500/v2/_catalog | jq -r '.repositories[]'); do
  echo "=== $img ==="
  curl -s http://localhost:30500/v2/$img/tags/list | jq .
done
```

## FAQ

### Q: Does this mean the images are outdated?
**A:** No! Knative v1.15.0 is a specific released version. The images are exactly as they were when v1.15.0 was released. That's what you want for reproducibility.

### Q: Should I update to newer images?
**A:** Only if you want a newer Knative version (v1.16+). For v1.15.0, these are the correct images.

### Q: Will these old images have security vulnerabilities?
**A:** Possibly. Knative v1.15.0 is from May 2024. For production:
- Check Knative's security advisories
- Consider using a more recent version
- Use Harbor or similar registry with vulnerability scanning

### Q: Can I change the creation date?
**A:** Not recommended! Changing it would:
- Invalidate the image signature
- Break digest verification
- Make it harder to track which official version you have

### Q: How do I know which Knative version I'm running?
**A:** The version is in the image tag: **v1.15.0**

You can also check:
```bash
kubectl get knativeserving -n knative-serving -o jsonpath='{.items[0].spec.version}'
```

## Summary

✅ **"A year ago" is correct** - Knative v1.15.0 was released in May 2024

✅ **This proves authenticity** - Your mirrored images are genuine Knative images

✅ **Creation date ≠ Mirror date** - The date shows when built, not when copied

✅ **Expected for airgap** - You want exact copies of official releases

✅ **Security consideration** - For production, evaluate if you need a newer version

## Additional Resources

- Knative Releases: https://github.com/knative/serving/releases
- Knative Documentation: https://knative.dev/docs/
- Container Image Spec: https://github.com/opencontainers/image-spec

---

**Bottom Line**: The "a year ago" date is **correct**, **expected**, and actually **desirable** for an airgap deployment. It proves you have authentic, unmodified Knative v1.15.0 images! 🎉
