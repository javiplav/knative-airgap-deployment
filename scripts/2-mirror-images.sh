#!/bin/bash
set -e

# Load registry configuration if it exists
if [ -f registry-config.env ]; then
    source registry-config.env
    echo "Loaded registry configuration from registry-config.env"
else
    echo "Error: registry-config.env not found. Run ./1-setup-registry-simple.sh first."
    exit 1
fi

REGISTRY_URL=${1:-$REGISTRY_URL}
PROJECT=${2:-$REGISTRY_PROJECT}

if [ -z "$REGISTRY_URL" ]; then
    echo "Usage: $0 <registry-url> [project-name]"
    echo "Example: $0 localhost:30500 knative"
    exit 1
fi

echo "=== Mirroring Knative Images to Private Registry ==="
echo ""
echo "Target Registry: $REGISTRY_URL"
echo "Target Project: $PROJECT"
echo ""

# Check if docker/nerdctl is available
if command -v docker &> /dev/null; then
    CTR="docker"
elif command -v nerdctl &> /dev/null; then
    CTR="nerdctl"
else
    echo "Error: Neither docker nor nerdctl found. Please install one."
    exit 1
fi

echo "Using container runtime: $CTR"
echo ""

# Read images from file
if [ ! -f images.txt ]; then
    echo "Error: images.txt not found"
    exit 1
fi

# Count total images
TOTAL=$(grep -v '^#' images.txt | grep -v '^$' | wc -l | tr -d ' ')
CURRENT=0
SUCCESS=0
FAILED=0

echo ""
echo "Found $TOTAL images to mirror"
echo ""

# Create image mapping file for later use
MAPPING_FILE="image-mappings.txt"
> "$MAPPING_FILE"

# Process each image
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue

    CURRENT=$((CURRENT + 1))
    SOURCE_IMAGE="$line"

    # Extract image name and tag
    IMAGE_NAME=$(echo "$SOURCE_IMAGE" | awk -F'/' '{print $NF}' | cut -d: -f1)
    IMAGE_TAG=$(echo "$SOURCE_IMAGE" | awk -F':' '{print $NF}')

    # If no tag specified, use latest
    if [ "$IMAGE_TAG" = "$SOURCE_IMAGE" ]; then
        IMAGE_TAG="latest"
    fi

    # Simplify the target path
    TARGET_IMAGE="$REGISTRY_URL/$PROJECT-$IMAGE_NAME:$IMAGE_TAG"

    echo "[$CURRENT/$TOTAL] Processing: $SOURCE_IMAGE"
    echo "  -> Target: $TARGET_IMAGE"

    # Pull source image
    echo "  Pulling..."
    if ! $CTR pull "$SOURCE_IMAGE" 2>&1 | grep -v "Pulling from"; then
        echo "  ERROR: Failed to pull $SOURCE_IMAGE"
        FAILED=$((FAILED + 1))
        echo ""
        continue
    fi

    # Tag for target registry
    echo "  Tagging..."
    $CTR tag "$SOURCE_IMAGE" "$TARGET_IMAGE"

    # Push to target registry
    echo "  Pushing..."
    if ! $CTR push "$TARGET_IMAGE" 2>&1 | grep -v "Pushing"; then
        echo "  ERROR: Failed to push $TARGET_IMAGE"
        FAILED=$((FAILED + 1))
        echo ""
        continue
    fi

    # Save mapping
    echo "$SOURCE_IMAGE=$TARGET_IMAGE" >> "$MAPPING_FILE"
    SUCCESS=$((SUCCESS + 1))

    echo "  ✓ Complete"
    echo ""
done < images.txt

echo "=== Image Mirroring Complete! ==="
echo ""
echo "Summary:"
echo "  Total images: $TOTAL"
echo "  Successful: $SUCCESS"
echo "  Failed: $FAILED"
echo ""
echo "Image mappings saved to: $MAPPING_FILE"
echo ""
echo "Next steps:"
echo "  Run deployment script: ./3-deploy-airgap-simple.sh"
echo ""
