#!/bin/bash

REGISTRY_URL="localhost:30500"

echo "==================================="
echo "   Docker Registry Browser"
echo "==================================="
echo ""
echo "Registry: $REGISTRY_URL"
echo ""

# Function to list all repositories
list_repos() {
    echo "📦 All Repositories:"
    echo ""
    curl -s http://$REGISTRY_URL/v2/_catalog | jq -r '.repositories[]' | nl
    echo ""
}

# Function to show details of a specific image
show_image() {
    local image=$1
    echo "📋 Image: $image"
    echo ""

    # Get tags
    echo "Tags:"
    curl -s http://$REGISTRY_URL/v2/$image/tags/list | jq -r '.tags[]' | sed 's/^/  - /'
    echo ""

    # Get manifest for first tag
    local tag=$(curl -s http://$REGISTRY_URL/v2/$image/tags/list | jq -r '.tags[0]')
    if [ ! -z "$tag" ]; then
        echo "Manifest for $tag:"
        curl -s http://$REGISTRY_URL/v2/$image/manifests/$tag | jq -r '.history[0].v1Compatibility' | jq -r '.Size' | awk '{printf "  Size: %.2f MB\n", $1/1024/1024}'
    fi
    echo ""
}

# Function to show all images with details
show_all() {
    local repos=$(curl -s http://$REGISTRY_URL/v2/_catalog | jq -r '.repositories[]')

    echo "📦 Complete Registry Contents:"
    echo ""
    printf "%-35s %-15s %-15s\n" "IMAGE" "TAG" "SIZE"
    printf "%-35s %-15s %-15s\n" "-----" "---" "----"

    for repo in $repos; do
        local tags=$(curl -s http://$REGISTRY_URL/v2/$repo/tags/list | jq -r '.tags[]')
        for tag in $tags; do
            # Try to get size (this is approximate)
            local size=$(curl -s http://$REGISTRY_URL/v2/$repo/manifests/$tag | jq -r '.config.size // 0' | awk '{printf "%.1fMB", $1/1024/1024}')
            printf "%-35s %-15s %-15s\n" "$repo" "$tag" "$size"
        done
    done
    echo ""
}

# Main menu
case "${1:-menu}" in
    list)
        list_repos
        ;;
    show)
        if [ -z "$2" ]; then
            echo "Usage: $0 show <image-name>"
            exit 1
        fi
        show_image "$2"
        ;;
    all)
        show_all
        ;;
    *)
        list_repos
        echo "Usage:"
        echo "  $0 list           - List all repositories"
        echo "  $0 show <image>   - Show details of specific image"
        echo "  $0 all            - Show all images with details"
        echo ""
        echo "API Endpoints:"
        echo "  Catalog:  curl http://$REGISTRY_URL/v2/_catalog"
        echo "  Tags:     curl http://$REGISTRY_URL/v2/<image>/tags/list"
        echo "  Manifest: curl http://$REGISTRY_URL/v2/<image>/manifests/<tag>"
        echo ""
        ;;
esac
