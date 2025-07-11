# OpenList APT Repository

This repository contains the Debian package configuration for OpenList, designed to automatically create `.deb` packages for Ubuntu/Debian systems. It monitors the main OpenList repository for new releases and automatically builds corresponding DEB packages.

## Features

- **Automatic Version Detection**: Uses GitHub API to detect new OpenList releases
- **Multi-Architecture Support**: Builds for both `amd64` and `arm64` architectures
- **Automated Binary Download**: Downloads the latest binaries from OpenList releases
- **System Integration**: 
  - Installs to `/var/lib/openlist`
  - Creates systemd service for automatic startup
  - Creates wrapper script at `/usr/bin/openlist` for command-line access
  - Automatically adds `--force-bin-dir` to all commands
  - Manages user/group creation and cleanup
- **GitHub Releases**: Automatically creates releases with DEB packages
- **PPA Support**: Optional upload to Launchpad PPA

## Repository Structure

```
├── .github/workflows/
│   └── build-deb.yml    # GitHub Actions workflow
├── debian/
│   ├── control          # Package metadata and dependencies
│   ├── changelog        # Package version history
│   ├── compat          # Debhelper compatibility level
│   ├── rules           # Build rules (extracts pre-downloaded binaries)
│   ├── openlist.install # File installation mappings
│   ├── openlist.service # Systemd service definition
│   ├── postinst        # Post-installation script
│   ├── prerm           # Pre-removal script
│   └── postrm          # Post-removal script
├── build.sh            # Local build script
└── README.md           # This file
```

## Automated Workflow

The GitHub Actions workflow:

1. **Daily Check**: Runs daily at 2 AM UTC to check for new OpenList releases
2. **Version Detection**: Uses GitHub API to get the latest release from `OpenListTeam/OpenList`
3. **Duplicate Check**: Verifies if this version was already built
4. **Binary Download**: Downloads `openlist-linux-amd64.tar.gz` and `openlist-linux-arm64.tar.gz`
5. **Package Building**: Creates DEB packages for both architectures
6. **Release Creation**: Creates a GitHub release with the DEB packages
7. **PPA Upload**: Optionally uploads to Launchpad PPA (if configured)

## Local Building

### Prerequisites

- `jq` (for JSON parsing)
- `wget` or `curl`
- Debian packaging tools (`debhelper`, `devscripts`, `build-essential`)

### Build Latest Version

```bash
chmod +x build.sh
./build.sh
```

### Build Specific Version

```bash
./build.sh --version 1.2.3 --arch amd64
```

### Build Script Options

- `-v, --version VERSION`: Set package version (default: fetch latest from GitHub)
- `-a, --arch ARCH`: Set architecture (amd64 or arm64, default: amd64)
- `-d, --debug`: Enable debug output
- `-h, --help`: Show help message

## GitHub Actions Configuration

### Automatic Triggers

- **Schedule**: Daily at 2 AM UTC
- **Manual**: Via workflow dispatch

### Required Secrets (for PPA upload)

Configure these secrets in your GitHub repository settings:

- `GPG_PRIVATE_KEY`: Your GPG private key for signing packages
- `GPG_PASSPHRASE`: Passphrase for your GPG key
- `GPG_KEY_ID`: Your GPG key ID
- `LAUNCHPAD_EMAIL`: Your Launchpad email address

### Repository Variables

- `ENABLE_PPA_UPLOAD`: Set to `'true'` to enable PPA uploads (optional)

## Installation

### From GitHub Releases

```bash
# Download latest release
wget https://github.com/OpenListTeam/OpenList-APT/releases/latest/download/openlist_VERSION-1_amd64.deb

# Install
sudo dpkg -i openlist_VERSION-1_amd64.deb
sudo apt-get install -f  # Fix any dependency issues
```

### From PPA (if configured)

```bash
sudo add-apt-repository ppa:openlist/ppa
sudo apt update
sudo apt install openlist
```

## Service Management

The package installs a systemd service that starts automatically:

```bash
# Check service status
sudo systemctl status openlist

# Start/stop/restart service
sudo systemctl start openlist
sudo systemctl stop openlist
sudo systemctl restart openlist

# View logs
sudo journalctl -u openlist -f
```

## Command Line Usage

After installation, OpenList is available in the PATH:

```bash
openlist --help
openlist server
openlist version
```

**Important**: The `/usr/bin/openlist` command is a wrapper script that automatically adds `--force-bin-dir` to all commands. So when you run:
- `openlist server` → actually executes `openlist server --force-bin-dir`
- `openlist --help` → actually executes `openlist --help --force-bin-dir`
- Any command → automatically gets `--force-bin-dir` appended

The actual binary is located at `/var/lib/openlist/openlist` with a wrapper script at `/usr/bin/openlist`.

## File Locations

- **Binary**: `/var/lib/openlist/openlist`
- **Wrapper Script**: `/usr/bin/openlist`
- **Working Directory**: `/var/lib/openlist`
- **Service File**: `/etc/systemd/system/openlist.service`
- **User/Group**: `openlist:openlist`

## Binary Sources

The package automatically downloads the appropriate binary from:
- AMD64: `https://github.com/OpenListTeam/OpenList/releases/latest/download/openlist-linux-amd64.tar.gz`
- ARM64: `https://github.com/OpenListTeam/OpenList/releases/latest/download/openlist-linux-arm64.tar.gz`

## Uninstallation

```bash
# Remove package but keep configuration
sudo apt remove openlist

# Remove package and all configuration/data
sudo apt purge openlist
```

## Troubleshooting

### Service Won't Start

Check the service logs:
```bash
sudo journalctl -u openlist -n 50
```

### Permission Issues

Ensure proper ownership:
```bash
sudo chown -R openlist:openlist /var/lib/openlist
sudo chmod 755 /var/lib/openlist/openlist
```

### Wrapper Script Issues

Check the wrapper script:
```bash
cat /usr/bin/openlist
```

If the wrapper script is missing or corrupted, recreate it:
```bash
sudo tee /usr/bin/openlist << 'EOF'
#!/bin/bash
# OpenList wrapper script
# Automatically adds --force-bin-dir to all commands

BINARY="/var/lib/openlist/openlist"

# Check if the binary exists
if [ ! -x "$BINARY" ]; then
    echo "Error: OpenList binary not found at $BINARY"
    exit 1
fi

# Check if --force-bin-dir is already present in arguments
if [[ "$*" != *"--force-bin-dir"* ]]; then
    # Add --force-bin-dir to all commands
    exec "$BINARY" "$@" --force-bin-dir
else
    # --force-bin-dir already present, pass through as-is
    exec "$BINARY" "$@"
fi
EOF
sudo chmod +x /usr/bin/openlist
```

### Direct Binary Access

If you need to run the binary without the wrapper script:
```bash
/var/lib/openlist/openlist --help
/var/lib/openlist/openlist server
```

## Development

### Testing Locally

1. Clone this repository
2. Run the build script: `./build.sh`
3. Install the generated package: `sudo dpkg -i ../openlist_*.deb`
4. Test the service: `sudo systemctl status openlist`
5. Test the wrapper: `openlist --help`

### Contributing

1. Fork this repository
2. Make your changes
3. Test locally
4. Submit a pull request

## License

This packaging configuration follows the same license as the main OpenList project.