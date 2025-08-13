#!/bin/bash

set -e

# Default values
VERSION=""
ARCH="amd64"
USE_LATEST=true
DEBUG=false

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
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -v, --version VERSION    Set package version (default: fetch latest from GitHub)"
            echo "  -a, --arch ARCH         Set architecture (amd64 or arm64, default: amd64)"
            echo "  -d, --debug             Enable debug output"
            echo "  -h, --help              Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Enable debug output if requested
if [ "$DEBUG" = "true" ]; then
    set -x
fi

# Validate architecture
if [[ "$ARCH" != "amd64" && "$ARCH" != "arm64" ]]; then
    echo "Error: Architecture must be either 'amd64' or 'arm64'"
    exit 1
fi

echo "=== OpenList DEB Package Builder ==="
echo "Debug mode: $DEBUG"
echo "Architecture: $ARCH"

# Get latest version from GitHub if not specified
if [[ "$USE_LATEST" == "true" ]]; then
    echo "Fetching latest OpenList Desktop version from GitHub..."
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required to fetch version from GitHub API"
        echo "Please install jq or specify version manually with -v option"
        echo "On Ubuntu/Debian: sudo apt-get install jq"
        exit 1
    fi
    
    # Get latest release info with better error handling
    echo "Calling GitHub API..."
    RELEASE_INFO=$(curl -s "https://api.github.com/repos/OpenListTeam/OpenList-Desktop/releases/latest")
    
    if [ "$DEBUG" = "true" ]; then
        echo "API Response:"
        echo "$RELEASE_INFO" | jq '.' || echo "Failed to parse JSON"
    fi
    
    TAG_NAME=$(echo "$RELEASE_INFO" | jq -r '.tag_name // empty')
    
    if [ -z "$TAG_NAME" ] || [ "$TAG_NAME" = "null" ] || [ "$TAG_NAME" = "empty" ]; then
        echo "Error: Failed to get tag_name from API response"
        echo "Trying alternative approach..."
        
        # Try to get the first release if latest fails
        RELEASE_INFO=$(curl -s "https://api.github.com/repos/OpenListTeam/OpenList-Desktop/releases" | jq '.[0]')
        TAG_NAME=$(echo "$RELEASE_INFO" | jq -r '.tag_name // empty')
        
        if [ -z "$TAG_NAME" ] || [ "$TAG_NAME" = "null" ] || [ "$TAG_NAME" = "empty" ]; then
            echo "Error: Still failed to get tag_name"
            echo "Using fallback version"
            TAG_NAME="v1.0.0"
        fi
    fi
    
    VERSION=${TAG_NAME#v}  # Remove 'v' prefix if present
    
    if [[ "$VERSION" == "null" || -z "$VERSION" ]]; then
        echo "Error: Failed to fetch latest version from GitHub"
        exit 1
    fi
    
    echo "Latest version found: $VERSION (tag: $TAG_NAME)"
else
    TAG_NAME="v$VERSION"
fi

# Ensure version is clean (no 'v' prefix) for debian package
CLEAN_VERSION=$(echo "$VERSION" | sed 's/^v//')

echo "=== Version Information ==="
echo "Original TAG_NAME: $TAG_NAME"
echo "Extracted VERSION: $VERSION"
echo "Clean VERSION for debian: $CLEAN_VERSION"

# Validate version format
if [[ ! "$CLEAN_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+.*$ ]]; then
    echo "Error: Version format is invalid: $CLEAN_VERSION"
    echo "Expected format: x.y.z (e.g., 1.0.0)"
    exit 1
fi

echo "Building OpenList Desktop DEB package..."
echo "Version: $CLEAN_VERSION"
echo "Architecture: $ARCH"

# Check for required tools
echo "=== Checking for required tools ==="
MISSING_TOOLS=()

for tool in wget tar dpkg-buildpackage debhelper; do
    if ! command -v $tool &> /dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo "Error: Missing required tools: ${MISSING_TOOLS[*]}"
    echo "Please install them:"
    echo "sudo apt-get install wget tar debhelper devscripts build-essential"
    exit 1
fi

# Download binary
echo "=== Downloading OpenList binary for $ARCH ==="
DOWNLOAD_URL="https://github.com/OpenListTeam/OpenList-Desktop/releases/download/$TAG_NAME/OpenList-Desktop-$CLEAN_VERSION.tar.gz"
echo "Download URL: $DOWNLOAD_URL"

if ! wget -O "OpenList-Desktop-$CLEAN_VERSION.tar.gz" "$DOWNLOAD_URL"; then
    echo "Error: Failed to download binary for $CLEAR_VERSION"
    echo "Please check if the release exists and the URL is correct"
    exit 1
fi

# Verify download
if [ ! -f "OpenList-Desktop-$CLEAN_VERSION.tar.gz" ]; then
    echo "Error: Downloaded file not found"
    exit 1
fi

echo "Downloaded file size: $(ls -lh OpenList-Desktop-$CLEAN_VERSION.tar.gz | awk '{print $5}')"

# Extract and verify binary
echo "=== Verifying downloaded binary ==="
mkdir -p test_extract
tar -xzf "OpenList-Desktop-$CLEAN_VERSION.tar.gz" -C test_extract

if [ ! -f "test_extract/openlist-desktop" ]; then
    echo "Error: Binary not found in archive"
    echo "Archive contents:"
    tar -tzf "OpenList-Desktop-$CLEAN_VERSION.tar.gz"
    exit 1
fi

echo "Binary file size: $(ls -lh test_extract/openlist-desktop | awk '{print $5}')"
rm -rf test_extract
echo "Binary verified successfully"

# Update changelog with clean version (no 'v' prefix)
echo "=== Updating changelog ==="
cat > debian/changelog << EOF
openlist-desktop ($CLEAN_VERSION-1) unstable; urgency=medium

  * DEB package built from OpenListTeam/OpenList-Desktop $TAG_NAME
  * Automated build for $ARCH architecture
  * Binary downloaded from official release

 -- Lycaon Constantine Cayde <kamialef2345@gmail.com>, original produce by OpenListTeam <openlistteam@gmail.com>  $(date -R)
EOF

echo "Generated changelog:"
cat debian/changelog

# Make scripts executable
chmod +x debian/rules
chmod +x debian/postinst
chmod +x debian/prerm
chmod +x debian/postrm

# Set environment variables for cross-compilation
export DEB_HOST_ARCH=$ARCH
export DEB_BUILD_OPTIONS="nocheck"

# Set cross-compilation environment for ARM64
if [ "$ARCH" = "arm64" ]; then
    export CC=aarch64-linux-gnu-gcc
    export DEB_BUILD_PROFILES="cross"
fi

echo "=== Building package ==="
echo "Building package with:"
echo "DEB_HOST_ARCH=$DEB_HOST_ARCH"
echo "DEB_BUILD_OPTIONS=$DEB_BUILD_OPTIONS"
echo "CC=$CC"
echo "DEB_BUILD_PROFILES=$DEB_BUILD_PROFILES"
echo "Package version: $CLEAN_VERSION-1"

# Build the package
echo "Starting dpkg-buildpackage..."
if [ "$DEBUG" = "true" ]; then
    dpkg-buildpackage -us -uc -a$ARCH
else
    dpkg-buildpackage -us -uc -a$ARCH 2>&1 | tee build.log
fi

# Cleanup
rm -f "OpenList-Desktop-$CLEAN_VERSION.tar.gz"

# Check for generated package
EXPECTED_DEB="openlist-desktop_${CLEAN_VERSION}-1_${ARCH}.deb"
if [ -f "$EXPECTED_DEB" ]; then
    echo "=== Build completed successfully! ==="
    echo "Package file: $EXPECTED_DEB"
elif [ -f "../$EXPECTED_DEB" ]; then
    echo "=== Build completed successfully! ==="
    echo "Package file: ../$EXPECTED_DEB"
else
    echo "Warning: Expected DEB file not found: $EXPECTED_DEB"
    echo "Available DEB files:"
    find . -name "*.deb" -o -name "../*.deb" 2>/dev/null || echo "No DEB files found"
    exit 1
fi

# Show package info if found
PACKAGE_PATH=""
if [ -f "../$EXPECTED_DEB" ]; then
    PACKAGE_PATH="../$EXPECTED_DEB"
elif [ -f "$EXPECTED_DEB" ]; then
    PACKAGE_PATH="$EXPECTED_DEB"
fi

if [ -n "$PACKAGE_PATH" ]; then
    echo ""
    echo "=== Package Information ==="
    dpkg-deb --info "$PACKAGE_PATH"
    echo ""
    echo "=== Package Contents ==="
    dpkg-deb --contents "$PACKAGE_PATH"
    echo ""
    echo "=== Installation Test ==="
    echo "To test the package, run:"
    echo "sudo dpkg -i $PACKAGE_PATH"
    echo "sudo apt-get install -f  # Fix any dependency issues"
    echo "sudo systemctl status openlist"
fi

echo ""
echo "=== Build Summary ==="
echo "✓ Version: $CLEAN_VERSION"
echo "✓ Architecture: $ARCH"
echo "✓ Package: $PACKAGE_PATH"
echo "✓ Build completed successfully!"
