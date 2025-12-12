# Orb - Bash Package Manager

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](https://github.com/stringmanolo/orb)

A lightweight, powerful package manager for Bash scripts. Install, manage, and bundle Bash libraries with ease.

## ✨ Features

- **📦 Package Management** - Install and manage Bash packages from GitHub repositories
- **🌐 Official & Custom Repos** - Use the official repository or add your own
- **🔒 Security Options** - Control insecure repository access with flags
- **📁 Local/Global Install** - Install packages locally (project-specific) or globally
- **🧩 Smart Bundling** - Bundle multiple scripts into a single file with automatic dependency resolution
- **📋 Dependency Tracking** - Automatic `orb.json` generation (similar to `package.json`)
- **🔍 Easy Discovery** - List available packages with detailed information
- **🐛 Debug Mode** - Comprehensive debugging output for troubleshooting

## 🚀 Installation

### Quick Install
```bash
curl -sSL https://raw.githubusercontent.com/stringmanolo/orb/main/install.sh | bash
```

### Manual Installation
```bash
git clone https://github.com/stringmanolo/orb.git
cd orb
sudo cp orb.sh /usr/local/bin/orb
sudo chmod +x /usr/local/bin/orb
```

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
```

### 3. Use in your script
Create `my_script.sh`:
```bash
#!/usr/bin/env bash
# orb import parseCLI 1.0.0

# Your code here
echo "Using parseCLI library"
```

### 4. Bundle for distribution
```bash
orb bundle my_script.sh bundled_script.sh
chmod +x bundled_script.sh
./bundled_script.sh
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
Packages must include an `orb.config` file at the repository root:

```bash
type='package'
packageName='parseCLI'
shortDescription='Utility to create CLI tools with argument parsing and color support'
version='1.0.0'
author='stringmanolo'

files:
"./parseCLI.sh" 'https://github.com/stringmanolo/parseCLI/raw/main/parseCLI.sh'
"./parseCLI_colors.sh" 'https://github.com/stringmanolo/parseCLI/raw/main/parseCLI_colors.sh'

bundleFiles=true
bundleFileName='parseCLI.bundle.sh'
isPackageBundlable=true
preserveFolderFiles=false
dependencies=''
compatibleShells='bash,zsh'
license='MIT'
repository='https://github.com/stringmanolo/parseCLI'
```

## 📁 Project Structure

### Local Installation
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

### Global Installation
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
└── installed/
```

## 🔐 Security

Orb provides multiple security levels:

1. **Official Repository Only** (default): Only installs from the official `orbpackages` repository
2. **Insecure Repositories**: Use `--allow-insecure-repos` to search in all added repositories
3. **Repository Validation**: All repositories must contain a valid `orb.config` file

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

### Example 2: Using Multiple Repositories
```bash
# Add a custom repository
orb --allow-insecure-repo https://github.com/user/bash-utils

# Install from custom repo
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

# See what's installed
ls ~/.orb/installed/parseCLI/
# Output: 1.0.0  1.1.0  2.0.0

# Uninstall old version
orb uninstall parseCLI 1.0.0
```

## 🐛 Debugging

Enable debug mode for detailed output:

```bash
# Set debug environment variable
export ORB_DEBUG=1

# Or run with debug for a single command
ORB_DEBUG=1 orb install parseCLI
```

Debug mode shows:
- HTTP requests and responses
- File operations
- Configuration parsing
- Installation steps

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

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by package managers like npm, pip, and cargo
- Built for the Bash community by Bash enthusiasts
- Special thanks to all contributors and package authors

## 🔗 Links

- [Official Repository](https://github.com/stringmanolo/orb)
- [Package Repository](https://github.com/stringmanolo/orbpackages)
- [Issues & Bugs](https://github.com/stringmanolo/orb/issues)
- [Contributing Guidelines](CONTRIBUTING.md)

---

**Orb** - Simplify your Bash scripting workflow. Install, manage, and bundle with confidence.
