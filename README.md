# Orb - Bash Package Manager

[![License: MIT](https://img.shields.io/badge/License-GPLV3-yellow.svg)](https://opensource.org/licenses/GPLV3)
[![Version](https://img.shields.io/badge/version-0.1.1-blue.svg)](https://github.com/stringmanolo/orb)

A lightweight, powerful package manager for Bash scripts. Install, manage, and bundle Bash libraries with ease.

## ✨ Features

- **📦 Package Management** - Install and manage Bash packages from GitHub repositories
- **🌐 Official & Custom Repos** - Use the official repository or add your own
- **🔒 Security Options** - Control insecure repository access with flags
- **📁 Local/Global Install** - Install packages locally (project-specific) or globally
- **🧩 Smart Bundling** - Bundle multiple scripts into a single file with automatic dependency resolution
- **📋 Dependency Tracking** - Automatic `orb.json` generation (similar to `package.json`)
- **🔄 Self-updating** - Automatic update checking and one-command updates
- **🔍 Easy Discovery** - List available packages with detailed information
- **🐛 Debug Mode** - Comprehensive debugging output for troubleshooting

## 🚀 Installation

### Method 1: One-Line Install (Recommended)
```bash
# Install with default options
curl -sSL https://raw.githubusercontent.com/stringmanolo/orb/main/install.sh | bash

# Install to user directory (no sudo required)
curl -sSL https://raw.githubusercontent.com/stringmanolo/orb/main/install.sh | bash -s -- --user

# Install to system directory (may need sudo)
curl -sSL https://raw.githubusercontent.com/stringmanolo/orb/main/install.sh | sudo bash -s -- --system
```

### Method 2: Manual Installation
```bash
# Clone the repository
git clone https://github.com/stringmanolo/orb.git
cd orb

# Install manually
chmod +x orb.sh
sudo cp orb.sh /usr/local/bin/orb

# Or to user directory
mkdir -p ~/.local/bin
cp orb.sh ~/.local/bin/orb
chmod +x ~/.local/bin/orb
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Method 3: Direct Download
```bash
# Download and install directly
wget https://raw.githubusercontent.com/stringmanolo/orb/main/orb.sh -O orb
chmod +x orb
sudo mv orb /usr/local/bin/
```

### Installation Options
| Option | Description |
|--------|-------------|
| `--user` | Install to `~/.local/bin` (recommended for users) |
| `--system` | Install to `/usr/local/bin` (requires sudo) |
| `--dir PATH` | Install to custom directory |
| `--no-check` | Skip dependency checks |
| `--check-update` | Check for updates after installation |
| `--force` | Force installation even if orb exists |

### Verification
After installation, verify it works:
```bash
orb --version
orb --help
```

### Dependencies
- **Required**: `curl` or `wget`
- **Optional**: `git`, `jq` (for advanced JSON manipulation in orb.json)

## 📖 Quick Start

### 1. Initialize a new project
```bash
orb init my-bash-project
```

### 2. Install a package
```bash
# Install locally (recommended for projects)
orb install parseCLI

# Install globally (available system-wide)
orb install parseCLI --global

# Install specific version
orb install parseCLI 1.0.0

# Install from insecure repositories
orb install parseCLI --allow-insecure-repos
```

### 3. Use in your script
Create `my_script.sh`:
```bash
#!/usr/bin/env bash
# orb import parseCLI 1.0.1

# Your code here
echo "Using $(cli color bold yellow parseCLI) library" # cli color is from parseCLI
```

### 4. Bundle for distribution
```bash
orb bundle my_script.sh bundled_script.sh
chmod +x bundled_script.sh
./bundled_script.sh
```

### 5. Keep orb updated
```bash
# Check for updates
orb --check-update

# Update to latest version
orb --update

# Force update without confirmation
orb --force-update
```

## 📦 Available Commands

### Package Management
| Command | Description |
|---------|-------------|
| `orb install <package> [version]` | Install a package (locally by default) |
| `orb install <package> --global` | Install a package globally |
| `orb uninstall <package>` | Uninstall a package |
| `orb list` | List available packages |
| `orb list --allow-insecure-repos` | List packages from all repositories |

### Project Management
| Command | Description |
|---------|-------------|
| `orb init <project-name>` | Initialize a new orb project |
| `orb bundle <input> [output]` | Bundle a script with its dependencies |
| `orb --version` | Show orb version |
| `orb --help` | Show help information |

### Repository Management
| Command | Description |
|---------|-------------|
| `orb --allow-insecure-repo <url>` | Add an insecure repository |

### Self-Update Commands
| Command | Description |
|---------|-------------|
| `orb --update`, `orb self-update` | Update orb to latest version |
| `orb --check-update` | Check for updates without installing |
| `orb --force-update` | Update without confirmation |

## 🔧 Configuration

### orb.json
Orb automatically creates an `orb.json` file in your project root to track dependencies:

```json
{
  "name": "my-bash-project",
  "version": "1.0.0",
  "description": "My awesome Bash project",
  "main": "main.sh",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "parseCLI": "1.0.0"
  },
  "devDependencies": {},
  "keywords": [],
  "author": "",
  "license": "ISC"
}
```

### Package Configuration (orb.config)
Packages must include an `orb.config` file at the repository root (only main or master branchs):

```bash
type='package'
packageName='parseCLI'
shortDescription='Utility to create CLI tools with argument parsing and color support'
version='1.0.0'
author='stringmanolo'

files:
"./other_languages/bash/parseCLI" 'https://github.com/stringmanolo/simpleArgumentsParser/raw/master/other_languages/bash/parseCLI'

bundleFiles=true
bundleFileName='parseCLI.bundle.sh'
isPackageBundlable=true
preserveFolderFiles=false
dependencies=''
compatibleShells='bash,zsh'
license='MIT'
repository='https://github.com/stringmanolo/parseCLI'
```

### Repository Configuration
Add custom repositories:
```bash
orb --allow-insecure-repo https://github.com/user/bash-utils
```

The repository will be added to `~/.orb/repos/` and can be used with `--allow-insecure-repos` flag.

## 📁 Project Structure

### Local Installation (Project-Specific)
```
my-project/
├── .orb/
│   └── installed/
│       └── parseCLI/
│           └── 1.0.0/
│               ├── orb.config
│               ├── .source
│               └── parseCLI.sh
├── orb.json
└── my_script.sh
```

### Global Installation (System-Wide)
```
~/.orb/
├── installed/
│   └── parseCLI/
│       └── 1.0.0/
│           ├── orb.config
│           ├── .source
│           └── parseCLI.sh
├── cache/
├── repos/
│   └── official
└── installed/
```

### Orb Home Directory
```
~/.orb/
├── cache/          # Downloaded package cache
├── installed/      # Globally installed packages
├── repos/          # Custom repository configurations
└── .last_update_check  # Timestamp for update checking
```

## 🔐 Security

Orb provides multiple security levels:

### Security Levels
1. **Official Repository Only** (default) - Only installs from the official `orbpackages` repository
2. **Insecure Repositories** - Use `--allow-insecure-repos` to search in all added repositories
3. **Repository Validation** - All repositories must contain a valid `orb.config` file

### Safe Defaults
- **HTTPS only**: All downloads use HTTPS
- **Repository validation**: Each repository must have valid `orb.config`
- **User confirmation**: Package installation requires confirmation
- **Secure bundling**: Bundled scripts maintain original permissions

## 🎯 Examples

### Example 1: Complete Workflow
```bash
# Create a new project
orb init my-cli-tool

# Install dependencies
orb install parseCLI
orb install colors

# Create your main script
cat > cli.sh << 'EOF'
#!/usr/bin/env bash
# orb import parseCLI
# orb import colors

# Use the libraries
echo "My awesome CLI tool"
EOF

# Bundle for distribution
orb bundle cli.sh dist/cli_bundled.sh

# Run it
./dist/cli_bundled.sh
```

### Example 2: Managing Multiple Repositories
```bash
# Add custom repositories
orb --allow-insecure-repo https://github.com/user/bash-utils
orb --allow-insecure-repo https://github.com/company/internal-tools

# Install from custom repos
orb install cool-tool --allow-insecure-repos

# List all available packages
orb list --allow-insecure-repos
```

### Example 3: Version Management
```bash
# Install specific version
orb install parseCLI 1.0.0

# Install latest version
orb install parseCLI

# See installed versions
ls ~/.orb/installed/parseCLI/
# Output: 1.0.0  1.1.0  2.0.0

# Uninstall specific version
orb uninstall parseCLI 1.0.0

# Uninstall all versions
orb uninstall parseCLI --force
```

### Example 4: Development Workflow
```bash
# Initialize project
orb init my-library

# Create package configuration
cat > orb.config << 'EOF'
type='package'
packageName='my-library'
version='0.1.0'
author='Your Name'
files:
"./lib.sh" 'https://github.com/you/my-library/raw/main/lib.sh'
EOF

# Test bundling locally
orb bundle test.sh test_bundled.sh
```

## 🔍 Debugging

Enable debug mode for detailed output:

```bash
# Set debug environment variable
export ORB_DEBUG=1

# Or run with debug for a single command
ORB_DEBUG=1 orb install parseCLI
```

### Debug Output Includes:
- HTTP requests and responses with status codes
- File operations and permissions
- Configuration parsing details
- Installation step-by-step progress
- Error stack traces

### Common Debug Scenarios:
```bash
# Debug installation failures
ORB_DEBUG=1 orb install missing-package

# Debug bundling issues
ORB_DEBUG=1 orb bundle script.sh

# Debug repository access
ORB_DEBUG=1 orb list --allow-insecure-repos
```

## 🚨 Troubleshooting

### Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| `orb: command not found` | Add install directory to PATH: `export PATH="$PATH:~/.local/bin"` |
| `Permission denied` | Use `--user` flag or install with sudo |
| `Package not found` | Check spelling or use `--allow-insecure-repos` |
| `Failed to download` | Check internet connection or repository URL |
| `Version not found` | Specify exact version or check available versions |
| `Bundle not working` | Ensure package is marked as bundlable in orb.config |

### Getting Help
```bash
# Show all available commands
orb --help

# Check orb version and configuration
orb --version

# Enable verbose output
ORB_DEBUG=1 orb [command]
```

## 🔄 Self-Update System

Orb includes a robust self-update system:

### Automatic Update Checking
Orb automatically checks for updates once per week. You'll be notified if a new version is available.

### Update Commands
```bash
# Check for updates without installing
orb --check-update

# Update with confirmation
orb --update

# Force update without confirmation
orb --force-update

# Alternative commands
orb self-update
orb upgrade
```

### Update Features
- **Safe backups**: Creates backup before updating
- **Rollback capability**: Automatically restores if update fails
- **Version validation**: Ensures new version is valid before applying
- **Permission checking**: Verifies write permissions before updating

## 🤝 Contributing

### Adding Packages to Official Repository
1. Fork the [orbpackages](https://github.com/stringmanolo/orbpackages) repository
2. Add your package entry to `orb.config`
3. Submit a pull request

### Creating Your Own Package
1. Create a GitHub repository with your Bash library
2. Add an `orb.config` file at the root
3. Structure your files according to the configuration
4. Add your repository: `orb --allow-insecure-repo https://github.com/you/your-package`

### Development
1. Clone the repository:
   ```bash
   git clone https://github.com/stringmanolo/orb.git
   cd orb
   ```

2. Make your changes to `orb.sh`

3. Test your changes:
   ```bash
   ./orb.sh --help
   ./orb.sh list
   ```

4. Submit a pull request with a clear description of changes

### Reporting Issues
- Check existing issues before creating new ones
- Include orb version: `orb --version`
- Include debug output: `ORB_DEBUG=1 orb [command]`
- Describe expected vs actual behavior

## 📄 License

GPLV3 License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by package managers like npm, pip, and cargo
- Built for the Bash community by Bash enthusiasts
- Special thanks to all contributors and package authors

## 🔗 Links

- [Official Repository](https://github.com/stringmanolo/orb)
- [Package Repository](https://github.com/stringmanolo/orbpackages)
- [Issues & Bugs](https://github.com/stringmanolo/orb/issues)
- [Install Script](https://raw.githubusercontent.com/stringmanolo/orb/main/install.sh)

---

**Orb** - Simplify your Bash scripting workflow. Install, manage, and bundle with confidence.

*"Because Bash deserves great package management too."*
