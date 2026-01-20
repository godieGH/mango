# Mango 🥭

> **A modern package manager for SwaziLang**

Mango is a prototype package manager written in SwaziLang that acts as a reference implementation for Swazi's future built-in package management system. It runs externally today, but its architecture and behavior are intentionally designed to mirror what the Swazi internal package manager will eventually provide natively inside the Swazi runtime.

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Commands](#commands)
- [Package Manifest](#package-manifest)
- [Native Addons](#native-addons)
- [Registry](#registry)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [License](#license)

---

## Features

✨ **Modern Package Management**
- Semantic versioning with flexible version ranges (`^`, `~`, `>=`, etc.)
- Automatic dependency resolution with BFS graph traversal
- Lockfile for reproducible builds
- Content-addressable package cache

🔒 **Security & Integrity**
- SHA-256 checksum verification for all downloads
- Integrity checks on cached packages
- Manifest hash validation for lockfile freshness

🛠️ **Native Addon Support**
- Automatic detection and building of C/C++ addons
- CMake and Make build system support
- Build requirement validation (compiler versions, tools)
- Cross-platform build configuration

🌍 **Global & Local Packages**
- Install packages locally per-project or globally system-wide
- Automatic bin script shim generation for global CLIs
- Nested dependency linking with isolated vendor directories

📦 **Developer Experience**
- Rich CLI with colorized output
- Interactive search and browse commands
- Detailed package information display
- Dry-run mode for publish and pack operations

---

## Installation

### Prerequisites

- **SwaziLang** runtime installed
- **Git** (for cloning)
- **Optional**: CMake, Make, GCC/Clang (for packages with native addons)

### Install Mango

```bash
# Clone the repository
git clone https://github.com/godieGH/mango.git
cd mango

# rename app.sl to mango

# Make executable
chmod +x mango

# Run setup
./mango setup

# Add to PATH (follow the instructions from setup command)
export PATH="$HOME/.swazi/globals:$PATH"
```

---

## Quick Start

### Initialize Mango

```bash
# First-time setup
mango setup
```

### Create an Account

```bash
# Register on the registry
mango register

# Or login if you have an account
mango login
```

### Install Packages

```bash
# Install from swazi.json
mango install

# Install specific packages
mango install chalk http-body

# Install with version range
mango install chalk@^1.0.0

# Install globally
mango install -g swazi-cli
```

### Search & Browse

```bash
# Search for packages
mango search "web framework"

# Get package info
mango info chalk

# Browse popular packages
mango browse --sort popular --limit 20
```

### Publish a Package

```bash
# Create package tarball
mango pack

# Test publish (dry run)
mango publish --dry-run

# Publish to registry
mango publish
```

---

## Commands

### Package Management

#### `mango install [packages...]`
Install packages from the registry.

**Options:**
- `-g, --global` - Install globally

**Examples:**
```bash
mango install
mango install chalk@^1.0.0 http-body@latest
mango install -g swazi-cli
```

**Version Ranges:**
- `1.2.3` - Exact version
- `^1.2.3` - Compatible (>=1.2.3 <2.0.0)
- `~1.2.3` - Patch updates (>=1.2.3 <1.3.0)
- `>=1.0.0` - Greater than or equal
- `latest` - Latest version
- `*` - Any version

#### `mango unlink <packages...>`
Remove packages from project or global installation.

**Options:**
- `-g, --global` - Unlink global packages
- `-s, --save` - Remove from manifest

**Examples:**
```bash
mango unlink chalk
mango unlink -g swazi-cli --save
```

#### `mango update [packages...]`
Update packages to their latest compatible versions.

**Options:**
- `-g, --global` - Update global packages

**Examples:**
```bash
mango update                 # Update all
mango update chalk           # Update specific
mango update chalk@^2.0.0    # Update with new range
```

#### `mango list`
List installed packages.

**Options:**
- `-g, --global` - List global packages

**Examples:**
```bash
mango list
mango list -g
```

---

### Discovery

#### `mango search <query>`
Search for packages in the registry.

**Options:**
- `--limit <n>` - Number of results (default: 20)
- `--offset <n>` - Pagination offset (default: 0)

**Examples:**
```bash
mango search http
mango search "web framework" --limit 10
```

#### `mango info <package>`
Show detailed package information.

**Examples:**
```bash
mango info chalk
mango info @scope/package
```

#### `mango browse`
Browse available packages.

**Options:**
- `--sort <type>` - Sort by `recent` or `popular` (default: recent)
- `--limit <n>` - Number of results (default: 20)

**Examples:**
```bash
mango browse
mango browse --sort popular --limit 30
```

---

### Publishing

#### `mango pack`
Create a tarball of your package.

**Options:**
- `--dry-run` - Test without creating file

**Examples:**
```bash
mango pack
mango pack --dry-run
```

#### `mango publish`
Publish package to the registry.

**Options:**
- `--dry-run` - Test without uploading

**Examples:**
```bash
mango publish
mango publish --dry-run
```

---

### Account Management

#### `mango register`
Create a new registry account (interactive).

#### `mango login`
Log in to the registry (interactive).

---

### Setup

#### `mango setup`
Initialize Mango global directories and show PATH setup instructions.

**Creates:**
- `~/.swazi/cache` - Downloaded tarballs
- `~/.swazi/vendor` - Extracted packages
- `~/.swazi/globals` - Global bin shims
- `~/.swazi/global-manifest.json` - Global package registry

---

## Package Manifest

Your `swazi.json` file defines your package:

```json
{
  "name": "my-package",
  "version": "1.0.0",
  "description": "A sample package",
  "author": "Your Name",
  "license": "MIT",
  "main": "index.sl",
  "bin": {
    "my-cli": "bin/cli.sl"
  },
  "vendor": {
    "chalk": "^1.0.0",
    "http-body": "~2.0.0"
  }
}
```

### Fields

- **name** - Package name (required)
- **version** - Semantic version (required)
- **description** - Short description
- **author** - Package author
- **license** - License identifier
- **main** - Entry point file
- **bin** - Executable scripts (object or string)
- **vendor** - Dependencies
- **repository** - Repository URL or object
- **homepage** - Project homepage
- **keywords** - Array of keywords

---

## Native Addons

Mango supports packages with C/C++ native addons that are built during installation.

### Build Configuration

Add a `build` section to your `swazi.json`:

```json
{
  "name": "image-processor",
  "version": "1.0.0",
  "build": {
    "requires": {
      "cmake": ">=3.10",
      "g++": ">=7.0",
      "make": "*"
    },
    "buildDir": "addons",
    "generator": "Unix Makefiles",
    "cmakeArgs": [
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON"
    ],
    "buildArgs": [
      "--config Release",
      "--parallel 4"
    ],
    "install": false
  }
}
```

### Build Fields

- **requires** - Build tool requirements with version constraints
- **buildDir** - Build output directory (default: `addons`)
- **generator** - CMake generator (default: `Unix Makefiles`)
- **cmakeArgs** - Arguments passed to `cmake` configure
- **buildArgs** - Arguments passed to `cmake --build`
- **install** - Run `cmake --install` after build (default: false)

### Project Structure

```
my-package/
├── src/
│   └── addon.cpp
├── CMakeLists.txt
├── swazi.json
└── index.sl
```

### Build Process

1. **Requirement Check** - Validates all build tools and versions
2. **Configuration** - Runs CMake configure step
3. **Build** - Compiles native code
4. **Optional Install** - Installs built artifacts if enabled

---

## Registry

Mango uses a centralized registry for package distribution.

### Default Registry

```
http://localhost:8080
```

### Custom Registry

Set the `SWAZI_REGISTRY` environment variable:

```bash
export SWAZI_REGISTRY="https://registry.swazi-lang.org"
mango install chalk
```

### Registry API

The registry provides these endpoints:

- `POST /api/auth/register` - Register user
- `POST /api/auth/login` - Login user
- `POST /api/packages/upload` - Publish package
- `GET /api/packages/:name` - Get package metadata
- `GET /api/packages/:name/:version` - Get specific version
- `GET /api/packages/:name/:version/download` - Download package
- `GET /api/search` - Search packages
- `DELETE /api/packages/:name/:version` - Delete version

---

## Architecture

### Directory Structure

```
~/.swazi/
├── cache/              # Downloaded package tarballs
├── vendor/             # Extracted packages (global truth)
│   └── <name>/
│       └── <version>/
│           ├── vendor/ # Package's dependencies (symlinks)
│           └── ...
├── globals/            # Global bin shims (add to PATH)
└── global-manifest.json
```

### Local Project

```
my-project/
├── vendor/             # Symlinks to ~/.swazi/vendor
│   ├── chalk -> ~/.swazi/vendor/chalk/1.0.0
│   └── http-body -> ~/.swazi/vendor/http-body/2.0.1
├── swazi.json
└── swazi.lock
```

### Dependency Resolution

1. **Parse** package specs from manifest
2. **Resolve** version ranges using BFS graph traversal
3. **Lock** resolved versions with manifest hash
4. **Download** tarballs to cache with integrity verification
5. **Extract** to global vendor store
6. **Build** native addons if required
7. **Link** dependencies via symlinks

### Lockfile

The `swazi.lock` file ensures reproducible installs:

```toml
version = 1
created = "2025-01-20T10:30:00Z"
manifestHash = "abc123..."

root = ["chalk@1.0.0", "http-body@2.0.1"]

[packages."chalk@1.0.0"]
name = "chalk"
version = "1.0.0"
tarball = "chalk-1.0.0.tar.gz"
integrity = "sha256-..."
downloadUrl = "http://localhost:8080/api/packages/chalk/1.0.0/download"

[packages."chalk@1.0.0".dependencies]
```

---

## Environment Variables

- **SWAZI_REGISTRY** - Custom registry URL (default: `http://localhost:8080`)
- **HOME** / **USERPROFILE** - Used to locate `~/.swazi`

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

```bash
git clone https://github.com/swazi-lang/mango.git
cd mango
./mango setup
```

### Running Tests

```bash
# Run test suite
swazi test/

# Test specific command
./mango install chalk --dry-run
```

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

## Roadmap

- [ ] Workspace support for monorepos
- [ ] Private registry authentication tokens
- [ ] Package signing and verification
- [ ] Peer dependency resolution
- [ ] Optional dependencies
- [ ] Scripts (preinstall, postinstall)
- [ ] Package aliasing
- [ ] Offline mode
- [ ] Mirror/proxy support
- [ ] Integration with Swazi runtime (future)

---

## Credits

Developed by the SwaziLang team as a reference implementation for the future built-in package manager.

**Maintainers:**
- [godieGH](https://github.com/godieGH)

---

## Support

- **Documentation**: [https://swazi-lang.org/mango](https://swazi-lang.org/mango)
- **Issues**: [GitHub Issues](https://github.com/godieGH/mango/issues)
- **Discord**: [SwaziLang Community](https://discord.gg/swazi)

---

Made with ❤️ for the SwaziLang community