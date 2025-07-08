#!/bin/bash

set -e

# Default values
VERSION=""
ARCH="amd64"
USE_LATEST=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            USE_LATEST=false
            shift 2
            ;;
        -a|--arch)
            ARCH="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -v, --version VERSION    Set package version (default: fetch latest from GitHub)"
            echo "  -a, --arch ARCH         Set architecture (amd64 or arm64, default: amd64)"
            echo "  -h, --help              Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate architecture
if [[ "$ARCH" != "amd64" && "$ARCH" != "arm64" ]]; then
    echo "Error: Architecture must be either 'amd64' or 'arm64'"
    exit 1
fi

# Get latest version from GitHub if not specified
if [[ "$USE_LATEST" == "true" ]]; then
    echo "Fetching latest OpenList version from GitHub..."
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required to fetch version from GitHub API"
        echo "Please install jq or specify version manually with -v option"
        exit 1
    fi
    
    # Get latest release info
    RELEASE_INFO=$(curl -s "https://api.github.com/repos/OpenListTeam/OpenList/releases/latest")
    TAG_NAME=$(echo "$RELEASE_INFO" | jq -r '.tag_name')
    VERSION=${TAG_NAME#v}  # Remove 'v' prefix if present
    
    if [[ "$VERSION" == "null" || -z "$VERSION" ]]; then
        echo "Error: Failed to fetch latest version from GitHub"
        exit 1
    fi
    
    echo "Latest version found: $VERSION (tag: $TAG_NAME)"
else
    TAG_NAME="v$VERSION"
fi

echo "Building OpenList DEB package..."
echo "Version: $VERSION"
echo "Architecture: $ARCH"

# Download binary
echo "Downloading OpenList binary for $ARCH..."
DOWNLOAD_URL="https://github.com/OpenListTeam/OpenList/releases/download/$TAG_NAME/openlist-linux-$ARCH.tar.gz"
echo "Download URL: $DOWNLOAD_URL"

wget -O "openlist-linux-$ARCH.tar.gz" "$DOWNLOAD_URL"

# Verify download
if [ ! -f "openlist-linux-$ARCH.tar.gz" ]; then
    echo "Error: Failed to download binary for $ARCH"
    exit 1
fi

# Extract and verify binary
echo "Verifying downloaded binary..."
mkdir -p test_extract
tar -xzf "openlist-linux-$ARCH.tar.gz" -C test_extract

if [ ! -f "test_extract/openlist" ]; then
    echo "Error: Binary not found in archive"
    exit 1
fi

rm -rf test_extract
echo "Binary verified successfully"

# Update changelog
sed -i "s/openlist (.*)/openlist ($VERSION-1)/" debian/changelog
sed -i "s/-- OpenList Team.*/-- OpenList Team <team@openlist.io>  $(date -R)/" debian/changelog

# Make scripts executable
chmod +x debian/rules
chmod +x debian/postinst
chmod +x debian/prerm
chmod +x debian/postrm

# Set architecture for build
export DEB_HOST_ARCH=$ARCH

# Build the package
echo "Building package..."
dpkg-buildpackage -us -uc -a$ARCH

# Cleanup
rm -f "openlist-linux-$ARCH.tar.gz"

echo "Build completed successfully!"
echo "Package file: ../openlist_${VERSION}-1_${ARCH}.deb"