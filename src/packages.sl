// src/install-package.sl
tumia process
tumia path
tumia fs
tumia json
tumia http
tumia datetime
tumia crypto
tumia os
tumia subprocess

tumia chalk kutoka "vendor:chalk"

tumia toml kutoka "vendor:swazi-toml"

tumia {
  get_project_root,
  load_and_parse_manifestfile,
  package_name_is_valid,
  package_version_is_valid,
  compute_hash,
  validate_dependencies,
  extract_tar_gz
} kutoka "utils/helpers"
tumia "./utils/logger.swz"

// polyfill some functions
fs.mkdir = (path, opt?) => fs.makeDir(path, opt?.recursive)
fs.listdir = (a) => fs.listDir(a)
fs.readdir = (dir_path, opt?) => {
  data dir_path = path.resolve(dir_path)
  data options = {
    recursive: opt?.recursive au sikweli,
    withFileTypes: opt?.withFileTypes au sikweli,
    absolute: opt?.absolute au sikweli,
    filter: opt?.filter au null,
    ignore: opt?.ignore au [],
    sort: opt?.sort au null
  }

  data stack = [dir_path]
  data results = []

  wakati !stack.empty() {
    data current = stack.pop()

    jaribu {
      data entries = fs.listDir(current)

      kwa kila entry ktk entries {
        // Skip ignored entries
        kama options.ignore.kuna(entry) {
          endelea
        }

        data full_path = path.resolve(current, entry)
        data relative_path = path.relative(dir_path, full_path)

        // Get file type if needed
        data stat = fs.lstat(full_path)
        data is_dir = stat.isDir

        // Apply filter
        kama options.filter na !options.filter(entry) {
          endelea
        }
        // Add to results
        kama options.withFileTypes {
          results.push( {
            name: options.absolute ? full_path : relative_path,
            type: is_dir ? "directory" : (stat.isSymlink ? "symlink" : "file"),
            size: stat.size
          })
        } sivyo {
          results.push(options.absolute ? full_path : relative_path)
        }

        // Recurse into directories
        kama options.recursive na is_dir {
          stack.push(full_path)
        }
      }
    } makosa err {
      chapisha("Error reading directory " + current + ": " + err)
    }
  }

  // Sort if requested
  data type_rank = (t) => {
    kama t == "directory" {
      rudisha 0
    }
    kama t == "file" {
      rudisha 1
    }
    kama t == "symlink" {
      rudisha 2
    }
    rudisha 3
  }
  data compare_type = (a, b) => {
    data ra = type_rank(a.type)
    data rb = type_rank(b.type)
    kama ra < rb {
      rudisha -1
    }
    kama ra > rb {
      rudisha 1
    }
    rudisha 0
  }
  data compare_name = (a, b) => {
    data i = 0
    data len_a = a.size
    data len_b = b.size
    data min = len_a < len_b ? len_a : len_b

    wakati i < min {
      kama a[i] < b[i] {
        rudisha -1
      }
      kama a[i] > b[i] {
        rudisha 1
      }
      i = i + 1
    }

    // All equal so far → shorter string wins
    kama len_a < len_b {
      rudisha -1
    }
    kama len_a > len_b {
      rudisha 1
    }

    rudisha 0
  }
  data compare_size = (a, b) => {
    kama a.size < b.size {
      rudisha -1
    }
    kama a.size > b.size {
      rudisha 1
    }
    rudisha 0
  }

  kama (options.sort == "name") {
    results = results.sort((a, b) => {
      data a_name = options.withFileTypes ? a.name : a
      data b_name = options.withFileTypes ? b.name : b
      rudisha compare_name(a_name.toLower(), b_name.toLower())
    })
  }
  sivyo kama (options.sort == "type") {
    kama options.withFileTypes {
      results = results.sort((a, b) => compare_type(a, b))
    }
  }
  sivyo kama (options.sort == "size") {
    kama options.withFileTypes {
      results = results.sort((a, b) => compare_size(a, b))
    }
  }

  rudisha results
}

// gobal values
data(
  LOCAL_ROOT = (() => {
    jaribu {
      rudisha get_project_root(process.cwd())
    } makosa err {
      // Not in a project directory - return null
      // This is OK for global operations
      rudisha null
    }
  })(),
  GLOBAL_ROOT = (() => {
    data home = process.getEnv("HOME") || process.getEnv("USERPROFILE");
    data g_root = path.resolve(home, ".swazi");
    rudisha g_root
  })(),
  REGISTRY_URL = process.getEnv("SWAZI_REGISTRY") au "http://localhost:8080"
)

// ========================================
// Load specs from manifest (local or global)
// ========================================
kazi load_from_manifest(is_global) {
  kama is_global {
    data manifest = load_global_manifest()

    kama !manifest.vendor {
      LOG(INFO, "No dependencies found in global manifest")
      rudisha []
    }

    data specs = []
    kwa kila (name, version_range) ktk manifest.vendor {
      specs.push(name + "@" + version_range)
    }

    LOG(INFO, "Loaded " + specs.size + " dependencies from global manifest")
    rudisha specs

  } sivyo {
    // Local manifest
    kama !LOCAL_ROOT {
      LOG(ERROR, "Not in a project directory. Run this command from a project root or use -g for global install.")
      tupa "No project root found"
    }

    data manifest = load_and_parse_manifestfile(LOCAL_ROOT)

    kama !manifest.vendor {
      LOG(INFO, "No dependencies found in swazi.json")
      rudisha []
    }

    data specs = []
    kwa kila (name, version_range) ktk manifest.vendor {
      specs.push(name + "@" + version_range)
    }

    LOG(INFO, "Loaded " + specs.size + " dependencies from swazi.json")
    rudisha specs
  }
}

// ========================================
// Version range validation
// ========================================
kazi is_valid_version_range(range) {
  kama !range au ainaya range != ainaya "" {
    rudisha sikweli
  }

  range = range.trim()

  // Supported patterns:
  // - exact: 1.2.3
  // - caret: ^1.2.3 (allows minor/patch updates)
  // - tilde: ~1.2.3 (allows patch updates only)
  // - wildcard: *
  // - tags: latest, alpha, beta, next
  // - comparators: >=1.0.0, <2.0.0

  data patterns = [
    /^\*$/,
    // *
    /^(latest|alpha|beta|next)$/,
    // tags
    /^[~^]?\d+\.\d+\.\d+$/,
    // ^1.2.3, ~1.2.3, 1.2.3
    /^( >= | <= | > | <)\d+\.\d+\.\d+$/,
    // >=1.0.0
    /^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$/ // 1.0.0-alpha.1
  ]

  kwa kila p ktk patterns {
    kama p.test(range) {
      rudisha kweli
    }
  }

  rudisha sikweli
}

// ========================================
// Parse spec string: "math@^1.2.0" -> {name, range}
// ========================================
kazi parse_spec(spec) {
  kama ainaya spec != ainaya "" {
    tupa "Spec must be a string: " + spec
  }

  spec = spec.trim()

  kama !spec {
    tupa "Empty spec string"
  }

  // Split by last @ to support scoped packages: @org/pkg@1.0.0
  data last_at = spec.lastIndexOf("@")

  data name = null
  data range = null

  kama last_at <= 0 {
    // No version specified: "math" -> use "latest"
    name = spec
    range = "latest"
  } sivyo {
    name = spec.substr(0, last_at)
    range = spec.substr(last_at + 1)

    // Handle scoped package with no version: "@org/pkg"
    kama name.startsWith("@") na !range {
      name = spec
      range = "latest"
    }
  }

  kama !package_name_is_valid(name) {
    tupa "Invalid package name: " + name
  }

  kama !is_valid_version_range(range) {
    tupa "Invalid version range: " + range + " for package " + name
  }

  rudisha {
    name,
    range
  }
}

// ========================================
// Fetch package metadata from registry
// ========================================
kazi fetch_package_metadata(pkg_name) {
  LOG(HINT, "Fetching metadata for " + pkg_name)

  // Registry endpoint: GET /api/packages/:name
  data url = REGISTRY_URL + "/api/packages/" + pkg_name

  jaribu {
    data response = http.get(url, {
      headers: {
        "Accept": "application/json"
      }
    })

    data metadata = json.parse(response)

    kama !metadata.success {
      tupa "Registry error: " + (metadata.error au "Unknown error")
    }

    // Registry returns: { success: true, name, versions: {...}, latestVersion }
    rudisha metadata

  } makosa err {
    tupa "Failed to fetch " + pkg_name + ": " + err
  }
}

// ========================================
// Compare two semver versions
// Returns: -1 if a < b, 0 if equal, 1 if a > b
// ========================================
kazi compare_versions(a, b) {
  data a_parts = a.split(".").map(p => parseInt(p))
  data b_parts = b.split(".").map(p => parseInt(p))

  kwa kila i ktk [0, 1, 2] {
    kama a_parts[i] > b_parts[i] =>> rudisha 1
    kama a_parts[i] < b_parts[i] =>> rudisha -1
  }

  rudisha 0
}

// ========================================
// Match version range to concrete version
// ========================================
kazi resolve_version(versions, range) {
  // versions is object: { "1.0.0": {...}, "1.2.3": {...} }
  data available = Object.keys(versions).sort(compare_versions)

  kama available.empty() {
    tupa "No versions available"
  }

  kama range == "*" au range == "latest" {
    rudisha available[available.size - 1] // highest version
  }

  // Tag-based: beta, alpha, next
  kama ["alpha", "beta", "next"].kuna(range) {
    // For now, treat as latest
    LOG(WARN, "Tag '" + range + "' treated as 'latest'")
    rudisha available[available.size - 1]
  }

  // Exact version
  kama /^\d+\.\d+\.\d+$/.test(range) {
    kama available.kuna(range) {
      rudisha range
    }
    tupa "Exact version " + range + " not found"
  }

  // Caret: ^1.2.3 -> >=1.2.3 <2.0.0
  kama range.startsWith("^") {
    data target = range.substr(1)
    data parts = target.split(".")
    data major = parseInt(parts[0])

    kwa kila v ktk available.reverse() {
      data v_parts = v.split(".")
      data v_major = parseInt(v_parts[0])

      kama v_major == major na compare_versions(v, target) >= 0 {
        rudisha v
      }
    }
    tupa "No version matches ^" + target
  }

  // Tilde: ~1.2.3 -> >=1.2.3 <1.3.0
  kama range.startsWith("~") {
    data target = range.substr(1)
    data parts = target.split(".")
    data major = parseInt(parts[0])
    data minor = parseInt(parts[1])

    kwa kila v ktk available.reverse() {
      data v_parts = v.split(".")
      data v_major = parseInt(v_parts[0])
      data v_minor = parseInt(v_parts[1])

      kama v_major == major na v_minor == minor na compare_versions(v, target) >= 0 {
        rudisha v
      }
    }
    tupa "No version matches ~" + target
  }

  // Comparators: >=1.0.0, <2.0.0
  data comparator_match = (/^(>=|<=|>|<)(\d+\.\d+\.\d+)$/).match(range)
  kama comparator_match {
    data op = comparator_match[1]
    data target = comparator_match[2]

    kwa kila v ktk available.reverse() {
      data cmp = compare_versions(v, target)

      data matches = (
        (op == ">=" na cmp >= 0) au
        (op == "<=" na cmp <= 0) au
        (op == ">" na cmp > 0) au
        (op == "<" na cmp < 0)
      )

      kama matches {
        rudisha v
      }
    }
    tupa "No version matches " + range
  }

  tupa "Unsupported version range: " + range
}

// ========================================
// STAGE 1: Resolve dependency graph (BFS)
// ========================================
kazi resolve_all(specs, target_root) {
  LOG(INFO, "Resolving dependency graph...")

  data graph = {
    root: [],
    // Root-level packages ["math@1.2.3", ...]
    packages: {},
    // All resolved packages: "math@1.2.3" -> metadata
    edges: {},
    // Dependencies: "math@1.2.3" -> ["fmt@2.0.0", ...]
    buildRequired: [] // track packages needing builds
  }

  data queue = []
  data visited = {} // Prevent duplicate resolution: "math@^1.0.0" -> true

  // Parse and queue root specs
  kwa kila spec ktk specs {
    data parsed = parse_spec(spec)
    queue.push({
      name: parsed.name,
      range: parsed.range,
      parent: null,
      depth: 0
    })
  }

  // BFS dependency resolution
  wakati !queue.empty() {
    data current = queue.shift()
    data {
      name,
      range,
      parent,
      depth
    } = current

    // Create unique key for this resolution request
    data cache_key = name + "@" + range

    kama visited[cache_key] {
      endelea // Already resolved this exact request
    }
    visited[cache_key] = kweli

    LOG(HINT, "  ".rudia(depth) + "Resolving " + name + "@" + range)

    // Fetch metadata from registry
    data metadata = fetch_package_metadata(name)

    kama !metadata.versions au Object.keys(metadata.versions).empty() {
      tupa "No versions available for " + name
    }

    // Match version range to concrete version
    data resolved_version = resolve_version(metadata.versions, range)

    LOG(INFO, "  ".rudia(depth) + "✔ " + name + "@" + resolved_version)

    data pkg_key = name + "@" + resolved_version
    data version_data = metadata.versions[resolved_version]

    // Store package info
    kama !graph.packages[pkg_key] {
      graph.packages[pkg_key] = {
        name: name,
        version: resolved_version,
        tarball: version_data.artifactName,
        integrity: version_data.checksum,
        downloadUrl: REGISTRY_URL + "/api/packages/" + name + "/" + resolved_version + "/download",
        dependencies: version_data.manifest.vendor au {},
        manifest: version_data.manifest
      }

      graph.edges[pkg_key] = []

      kama version_data.manifest.build {
        graph.buildRequired.push(pkg_key)
      }
    }

    // Track root packages
    kama parent == null {
      graph.root.push(pkg_key)
    } sivyo {
      graph.edges[parent].push(pkg_key)
    }

    // Queue child dependencies
    kama version_data.manifest.vendor {
      kwa kila (dep_name, dep_range) ktk version_data.manifest.vendor {
        queue.push( {
          name: dep_name,
          range: dep_range,
          parent: pkg_key,
          depth: depth + 1
        })
      }
    }
  }

  LOG(INFO, "✔ Resolution complete: " + Object.keys(graph.packages).size + " packages")
  kama !graph.buildRequired.empty() {
    LOG(INFO, "  " + graph.buildRequired.size.str() + " package(s) require native builds")
  }
  rudisha graph
}

// ========================================
// STAGE 2: Create lock file
// ========================================
kazi create_lockfile(graph, target_root, manifest_hash) {
  LOG(INFO, "Creating lock file...")

  data lockdata = {
    version: 1,
    created: datetime.now().str(),
    manifestHash: manifest_hash,
    root: graph.root,
    packages: {}
  }

  // Flatten graph into lock structure
  kwa kila (pkg_key, info) ktk graph.packages {
    lockdata.packages[pkg_key] = {
      name: info.name,
      version: info.version,
      tarball: info.tarball,
      integrity: info.integrity,
      downloadUrl: info.downloadUrl,
      dependencies: {}
    }

    // Add resolved dependencies
    kwa kila dep_key ktk graph.edges[pkg_key] {
      data dep_info = graph.packages[dep_key]
      lockdata.packages[pkg_key].dependencies[dep_info.name] = dep_info.version
    }
  }

  // Write to disk
  data lock_path = path.resolve(target_root, "swazi.lock")
  fs.writeFile(lock_path, toml.stringify(lockdata))

  LOG(INFO, "✔ Lock file created: swazi.lock")
  rudisha lockdata
}

// ========================================
// STAGE 3: Download packages to cache
// ========================================
kazi download_packages(lockdata, target_root) {
  LOG(INFO, "Downloading packages...")

  data cache_dir = path.resolve(GLOBAL_ROOT, "cache")

  kama !fs.exists(cache_dir) {
    fs.mkdir(cache_dir, {
      recursive: kweli
    })
  }

  data downloaded = 0
  data cached = 0

  kwa kila (pkg_key, info) ktk lockdata.packages {
    data cache_path = path.resolve(cache_dir, info.tarball)

    // Check if already cached
    kama fs.exists(cache_path) {
      // Verify integrity
      data cached_data = fs.readFile(cache_path, {
        encoding: "binary"
      })
      data cached_hash = compute_hash(cached_data)

      kama cached_hash == info.integrity {
        LOG(HINT, "✔ Cached: " + info.tarball)
        cached++
        endelea
      } sivyo {
        LOG(WARN, "Cache corrupted, re-downloading: " + info.tarball)
        fs.remove(cache_path)
      }
    }

    // Download
    LOG(INFO, "Downloading " + pkg_key + "...")

    jaribu {
      data response = http.get(info.downloadUrl, {
        headers: {
          "Accept": "application/gzip"
        },
        encoding: "binary"
      })

      // Verify hash
      data download_hash = compute_hash(response)

      kama download_hash != info.integrity {
        fs.remove(cache_path) // Clean up if exists
        tupa "Integrity check failed for " + pkg_key +
        "\nExpected: " + info.integrity +
        "\nGot: " + download_hash
      }

      // Save to cache
      fs.writeFile(cache_path, response, {
        encoding: "binary"
      })
      LOG(INFO, "✔ Downloaded: " + info.tarball)
      downloaded++

    } makosa err {
      tupa "Failed to download " + pkg_key + ": " + err
    }
  }

  LOG(INFO, "✔ Downloads complete: " + downloaded + " downloaded, " + cached + " cached")
}

// ========================================
// STAGE 4: Extract to global vendor store
// ========================================
kazi extract_packages(lockdata) {
  LOG(INFO, "Extracting packages to vendor...")

  data vendor_dir = path.resolve(GLOBAL_ROOT, "vendor")
  data cache_dir = path.resolve(GLOBAL_ROOT, "cache")

  kama !fs.exists(vendor_dir) {
    fs.mkdir(vendor_dir, {
      recursive: kweli
    })
  }

  data extracted = 0
  data skipped = 0

  kwa kila (pkg_key, info) ktk lockdata.packages {
    data pkg_vendor_path = path.resolve(vendor_dir, info.name, info.version)

    // Skip if already extracted
    kama fs.exists(pkg_vendor_path) {
      LOG(HINT, "✔ Already extracted: " + pkg_key)
      skipped++
      endelea
    }

    LOG(INFO, "Extracting " + pkg_key + "...")

    jaribu {
      data cache_path = path.resolve(cache_dir, info.tarball)

      // Create package directory
      fs.mkdir(pkg_vendor_path, {
        recursive: kweli
      })

      // Extract tarball
      data tarball = fs.readFile(cache_path, {
        encoding: "binary"
      })
      data extracted_data = extract_tar_gz(tarball)

      // Write files
      kwa kila (file, idx) ktk extracted_data {
        data file_path = extracted_data[idx].name;
        data content = extracted_data[idx].content;
        data full_path = path.resolve(pkg_vendor_path, file_path)
        data dir = path.dirname(full_path)

        kama !fs.exists(dir) {
          fs.mkdir(dir, {
            recursive: kweli
          })
        }
        fs.writeFile(full_path, content, {
          encoding: "binary"
        })
      }

      LOG(INFO, "✔ Extracted: " + pkg_key)
      extracted++

    } makosa err {
      tupa "Failed to extract " + pkg_key + ": " + err
    }
  }

  LOG(INFO, "✔ Extraction complete: " + extracted + " extracted, " + skipped + " skipped")
}

// ========================================
// STAGE 5: Link dependencies (nested vendor or global bins)
// ========================================
kazi link_dependencies(lockdata, target_root, is_global) {
  LOG(INFO, "Linking dependencies...")

  data vendor_dir = path.resolve(GLOBAL_ROOT, "vendor")

  // First: Link each package's dependencies to their vendor/
  kwa kila (pkg_key, info) ktk lockdata.packages {
    data pkg_vendor_path = path.resolve(vendor_dir, info.name, info.version)
    data pkg_vendor_deps = path.resolve(pkg_vendor_path, "vendor")

    kama !info.dependencies au Object.keys(info.dependencies).empty() {
      endelea // No dependencies
    }

    kama !fs.exists(pkg_vendor_deps) {
      fs.mkdir(pkg_vendor_deps, {
        recursive: kweli
      })
    }

    kwa kila (dep_name, dep_version) ktk info.dependencies {
      data symlink_path = path.resolve(pkg_vendor_deps, dep_name)
      data target_path = path.resolve(vendor_dir, dep_name, dep_version)

      kama fs.exists(symlink_path) {
        endelea // Already linked
      }

      fs.symlink(target_path, symlink_path)
      LOG(HINT, "  Linked: " + pkg_key + " -> " + dep_name + "@" + dep_version)
    }
  }

  // Second: Link to appropriate location
  kama is_global {
    // Global install: Create bin shims in ~/.swazi/globals/
    data globals_dir = get_globals_dir()

    kama !fs.exists(globals_dir) {
      fs.mkdir(globals_dir, {
        recursive: kweli
      })
    }

    kwa kila (pkg_key, info) ktk lockdata.packages {
      // Only install bins for root-level packages
      data is_root = sikweli
      kwa kila root_key ktk lockdata.root au [] {
        kama root_key == pkg_key {
          is_root = kweli
          simama
        }
      }

      kama !is_root {
        endelea
      }

      install_global_bins(info.name, info.version, globals_dir)
    }

    LOG(INFO, "✔ Global bins installed to " + globals_dir)

  } sivyo {
    // Local install: Link to project vendor/
    data project_vendor = path.resolve(target_root, "vendor")

    kama !fs.exists(project_vendor) {
      fs.mkdir(project_vendor, {
        recursive: kweli
      })
    }

    kwa kila (pkg_key, info) ktk lockdata.packages {
      // Only link root-level packages
      data is_root = sikweli
      kwa kila root_key ktk lockdata.root au [] {
        kama root_key == pkg_key {
          is_root = kweli
          simama
        }
      }

      kama !is_root {
        endelea
      }

      data symlink_path = path.resolve(project_vendor, info.name)
      data target_path = path.resolve(vendor_dir, info.name, info.version)

      kama fs.exists(symlink_path) {
        fs.remove(symlink_path) // Remove old link
      }

      fs.symlink(target_path, symlink_path)
      LOG(INFO, "✔ Linked to project: " + info.name)
    }
  }

  LOG(INFO, "✔ Linking complete!")
}

// ========================================
// STAGE 6: Build native addons
// ========================================
kazi async build_packages(lockdata, graph, force_build) {
  kama !graph.buildRequired au graph.buildRequired.empty() {
    rudisha // No packages need building
  }

  LOG(INFO, "Building native addons...")

  data vendor_dir = path.resolve(GLOBAL_ROOT, "vendor")
  data all_requirements_satisfied = kweli
  data missing_tools = []

  // First pass: Check all requirements
  kwa kila pkg_key ktk graph.buildRequired {
    data info = graph.packages[pkg_key]
    data pkg_path = path.resolve(vendor_dir, info.name, info.version)

    data manifest = info.manifest
    kama !manifest {
      data manifest_path = path.resolve(pkg_path, "swazi.json")
      kama fs.exists(manifest_path) {
        jaribu {
          data content = fs.readFile(manifest_path, {
            encoding: "utf8"
          })
          manifest = json.parse(content)
        } makosa err {
          LOG(ERROR, "Failed to load manifest for " + info.name + "@" + info.version)
          endelea
        }
      } sivyo {
        LOG(WARN, "No manifest found for " + info.name + "@" + info.version)
        endelea
      }
    }

    data req_check = await check_build_requirements(manifest)

    kama !req_check.satisfied {
      all_requirements_satisfied = sikweli

      LOG(WARN, "Package " + info.name + "@" + info.version + " has unmet build requirements:")

      kwa kila missing ktk req_check.missing {
        LOG(WARN, "  • " + missing.tool + " " + missing.required + " - " + missing.reason)

        kama missing.current {
          LOG(WARN, "    Current: " + missing.current)
        }

        // Track unique missing tools
        data tool_key = missing.tool + "@" + missing.required
        data found = sikweli

        kwa kila mt ktk missing_tools {
          kama mt.tool == missing.tool na mt.version == missing.required {
            mt.packages.push(info.name)
            found = kweli
            simama
          }
        }

        kama !found {
          missing_tools.push( {
            tool: missing.tool,
            version: missing.required,
            packages: [info.name]
          })
        }
      }
    }
  }

  // If requirements not satisfied, show error and exit
  kama !all_requirements_satisfied {
    LOG(ERROR, "\n" + chalk.bold.red("Build requirements not satisfied!"))
    LOG(ERROR, "\nThe following tools are required:\n")

    kwa kila mt ktk missing_tools {
      LOG(ERROR, chalk.bold(mt.tool) + " " + chalk.cyan(mt.version))
      LOG(ERROR, "  Needed by: " + mt.packages.join(", "))
    }

    LOG(ERROR, "\nPlease install the required build tools and try again.")
    LOG(HINT, "\nCommon installation commands:")
    LOG(HINT, "  Ubuntu/Debian: sudo apt-get install cmake g++ make")
    LOG(HINT, "  macOS: brew install cmake")
    LOG(HINT, "  Windows: Install Visual Studio Build Tools")

    tupa "Missing build requirements"
  }

  // Second pass: Build packages
  data built = 0
  data cached = 0
  data failed = 0

  kwa kila pkg_key ktk graph.buildRequired {
    data info = graph.packages[pkg_key]
    data pkg_path = path.resolve(vendor_dir, info.name, info.version)

    // Load manifest from disk if not in memory
    data manifest = info.manifest
    kama !manifest {
      data manifest_path = path.resolve(pkg_path, "swazi.json")
      jaribu {
        data content = fs.readFile(manifest_path, {
          encoding: "utf8"
        })
        manifest = json.parse(content)
      } makosa err {
        LOG(ERROR, "Failed to load manifest for " + info.name)
        failed++
        endelea
      }
    }

    // Check build cache
    data cache_check = await check_build_cache(pkg_path, manifest.build, force_build)

    kama cache_check.valid {
      LOG(INFO, "✔ Using cached build for " + info.name + "@" + info.version)
      cached++
      endelea
    }

    LOG(HINT, "  Cache invalid: " + cache_check.reason)

    // Build
    data build_success = await build_native_addon(
      info.name,
      info.version,
      pkg_path,
      manifest.build // Use loaded manifest
    )

    kama build_success {
      // Save cache after successful build
      await save_build_cache(pkg_path, manifest.build)
      built++
    } sivyo {
      failed++
    }
  }

  kama built > 0 {
    LOG(INFO, "✔ Built " + built + " native addon(s)")
  }

  kama cached > 0 {
    LOG(INFO, "✔ Used cached builds for " + cached + " addon(s)")
  }

  kama failed > 0 {
    LOG(WARN, "⚠ " + failed + " native addon(s) failed to build")
  }
}


// ========================================
// Add package to manifest (local or global)
// ========================================
kazi add_to_manifest(specs, target_root, is_global) {
  data manifest = null
  data manifest_path = null

  kama is_global {
    manifest = load_global_manifest()
    manifest_path = get_global_manifest_path()
  } sivyo {
    manifest = load_and_parse_manifestfile(target_root)
    manifest_path = path.resolve(target_root, "swazi.json")
  }

  kama !manifest.vendor {
    manifest.vendor = {}
  }

  data added = []

  kwa kila spec ktk specs {
    data parsed = parse_spec(spec)

    kama !manifest.vendor[parsed.name] {
      manifest.vendor[parsed.name] = parsed.range
      added.push(parsed.name + "@" + parsed.range)
    }
  }

  kama !added.empty() {
    fs.writeFile(manifest_path, json.stringify(manifest, null, 2))
    data location = is_global ? "global manifest" : "swazi.json"
    LOG(INFO, "Added to " + location + ": " + added.join(", "))
  }
}

// ========================================
// Hash manifest vendor section for change detection
// ========================================
kazi hash_manifest(manifest) {

  data compute_hash = (_data) => {
    rudisha crypto.hash("sha256", _data).toStr("hex")
  }

  kama !manifest.vendor {
    rudisha compute_hash(json.stringify( {}))
  }

  // Normalize: for consistent hashing
  data vendor = manifest.vendor
  data sorted_keys = Object.keys(vendor).sort()
  
  data pairs = []
  kwa kila key ktk sorted_keys {
    pairs.push(`${key}:${json.stringify(vendor[key])}`)
  }

  // Hash the normalized vendor section
  data vendor_json = pairs.join("|")
  rudisha compute_hash(vendor_json)
}

// ========================================
// Load and parse lockfile if it exists
// ========================================
kazi load_lockfile(target_root) {
  data lock_path = path.resolve(target_root, "swazi.lock")

  kama !fs.exists(lock_path) {
    rudisha null
  }

  jaribu {
    data lock_content = fs.readFile(lock_path, {
      encoding: "utf8"
    })
    data lockdata = toml.parse(lock_content)
    rudisha lockdata
  } makosa err {
    LOG(WARN, "Failed to read lockfile: " + err)
    rudisha null
  }
}

// ========================================
// Main install command
// ========================================

kazi async install_package(cli) {
  ensure_setup()

  data is_global = cli.flags.global au sikweli

  // For local operations, ensure we're in a project directory
  kama !is_global na !LOCAL_ROOT {
    LOG(ERROR, "Not in a project directory.")
    LOG(ERROR, "Either run this command from a project root, or use -g for global install:")
    LOG(ERROR, "  swazi vendor install -g <package>")
    rudisha
  }

  data specs = []
  data target_root = is_global ? GLOBAL_ROOT : LOCAL_ROOT

  // Add new packages to manifest (if installing from CLI args)
  kama !cli.args.empty() {
    specs = cli.args;
    add_to_manifest(specs, target_root, is_global)
  }

  // Load manifest and compute hash
  data manifest = is_global ? load_global_manifest() : load_and_parse_manifestfile(target_root)
  data current_hash = hash_manifest(manifest)

  // Lockfile path differs for global vs local
  data lock_path = is_global ?
    path.resolve(GLOBAL_ROOT, "swazi.lock") :
    path.resolve(target_root, "swazi.lock")

  // Try to load existing lockfile
  data existing_lock = is_global ? load_lockfile(GLOBAL_ROOT) : load_lockfile(target_root)
  data should_use_lockfile = sikweli

  kama existing_lock != null {
    // Check if manifest hasn't changed
    kama existing_lock.manifestHash == current_hash {
      LOG(INFO, "Manifest unchanged, using existing lockfile")
      should_use_lockfile = kweli
    } sivyo {
      LOG(INFO, "Manifest changed, re-resolving dependencies")
    }
  } sivyo {
    LOG(INFO, "No lockfile found, resolving dependencies")
  }


  // Load specs from manifest
  specs = load_from_manifest(is_global)

  kama specs.empty() {
    LOG(INFO, "Nothing to install")
    rudisha
  }

  jaribu {
    data lockdata = null;
    data graph = null

    kama should_use_lockfile {
      // Use existing lockfile - skip resolution
      lockdata = existing_lock
      LOG(INFO, "✔ Using locked versions")
    } sivyo {
      // STAGE 1: Resolve all dependencies
      graph = resolve_all(specs, target_root)
      
      // STAGE 2: Create new lock file with manifest hash
      lockdata = create_lockfile(graph, target_root, current_hash)
    }


    // STAGE 3: Download packages
    download_packages(lockdata, target_root)

    // STAGE 4: Extract to global vendor
    extract_packages(lockdata)

    kama should_use_lockfile na !graph {
      data build_required = extract_build_required_from_lockfile(lockdata)

      kama !build_required.empty() {
        // Create minimal graph object for build stage
        graph = {
          buildRequired: build_required,
          packages: lockdata.packages
        }
      }
    }
    // STAGE 5: Build native addons (if needed)
    kama graph na graph.buildRequired {
      data force_build = cli.flags.forceBuild au sikweli
      await build_packages(lockdata, graph, force_build)
    }

    // STAGE 6: Link dependencies (or install global bins)
    link_dependencies(lockdata, target_root, is_global)

    data install_type = is_global ? "global" : "local"
    LOG(null, "✔ " + install_type + " installation complete!")

  } makosa error {
    LOG(ERROR, "Installation failed: " + error)
    tupa error
  }
}

// other commands
kazi unlink_package(cli) {
  ensure_setup()

  data is_global = cli.flags.global au sikweli
  // For local operations, ensure we're in a project directory
  kama !is_global na !LOCAL_ROOT {
    LOG(ERROR, "Not in a project directory.")
    LOG(ERROR, "Either run this command from a project root, or use -g for global unlink:")
    LOG(ERROR, "  swazi vendor unlink -g <package>")
    rudisha
  }
  data save = cli.flags.save au sikweli
  data package_names = cli.args

  kama package_names.empty() {
    LOG(ERROR, "Please specify package(s) to unlink")
    rudisha
  }

  jaribu {
    kama is_global {
      // Unlink global packages
      data globals_dir = get_globals_dir()
      data manifest = load_global_manifest()

      kwa kila pkg_name ktk package_names {
        // Get current version from manifest
        kama !manifest.vendor au !manifest.vendor[pkg_name] {
          LOG(WARN, pkg_name + " is not installed globally")
          endelea
        }

        data version_range = manifest.vendor[pkg_name]

        // Load global lockfile to get exact version
        data lockdata = load_lockfile(GLOBAL_ROOT)
        data pkg_version = null

        kama lockdata {
          kwa kila (pkg_key, info) ktk lockdata.packages {
            kama info.name == pkg_name {
              pkg_version = info.version
              simama
            }
          }
        }

        kama pkg_version {
          // Remove bin shims
          uninstall_global_bins(pkg_name, pkg_version, globals_dir)
        }

        // Remove from manifest if --save
        kama save {
          manifest.vendor.__proto__.delete(pkg_name)
          LOG(INFO, "Removed " + pkg_name + " from global manifest")
        }
      }

      kama save {
        save_global_manifest(manifest)

        // Re-resolve to update lockfile
        LOG(INFO, "Updating global lockfile...")
        data specs = load_from_manifest(kweli)

        kama !specs.empty() {
          data graph = resolve_all(specs, GLOBAL_ROOT)
          data new_hash = hash_manifest(manifest)
          create_lockfile(graph, GLOBAL_ROOT, new_hash)
        } sivyo {
          // No more packages, remove lockfile
          data lock_path = path.resolve(GLOBAL_ROOT, "swazi.lock")
          kama fs.exists(lock_path) {
            fs.remove(lock_path)
          }
        }
      }

    } sivyo {
      // Unlink local packages
      data project_vendor = path.resolve(LOCAL_ROOT, "vendor")
      data manifest = load_and_parse_manifestfile(LOCAL_ROOT)

      kwa kila pkg_name ktk package_names {
        data symlink_path = path.resolve(project_vendor, pkg_name)

        kama fs.exists(symlink_path) {
          fs.remove(symlink_path)
          LOG(INFO, "Unlinked " + pkg_name + " from project")
        } sivyo {
          LOG(WARN, pkg_name + " is not linked in project")
        }

        // Remove from manifest if --save
        kama save na manifest.vendor {
          manifest.vendor.__proto__.delete(pkg_name)
          LOG(INFO, "Removed " + pkg_name + " from swazi.json")
        }
      }

      kama save {
        data manifest_path = path.resolve(LOCAL_ROOT, "swazi.json")
        fs.writeFile(manifest_path, json.stringify(manifest, null, 2))

        // Re-resolve to update lockfile
        LOG(INFO, "Updating lockfile...")
        data specs = load_from_manifest(sikweli)

        kama !specs.empty() {
          data graph = resolve_all(specs, LOCAL_ROOT)
          data new_hash = hash_manifest(manifest)
          create_lockfile(graph, LOCAL_ROOT, new_hash)
        } sivyo {
          // No more packages, remove lockfile
          data lock_path = path.resolve(LOCAL_ROOT, "swazi.lock")
          kama fs.exists(lock_path) {
            fs.remove(lock_path)
          }
        }
      }
    }

    LOG(null, "✔ Unlink complete!")

  } makosa error {
    LOG(ERROR, "Unlink failed: " + error)
    tupa error
  }
}
kazi update_package(cli) {
  ensure_setup()

  data is_global = cli.flags.global au sikweli
  // For local operations, ensure we're in a project directory
  kama !is_global na !LOCAL_ROOT {
    LOG(ERROR, "Not in a project directory.")
    LOG(ERROR, "Either run this command from a project root, or use -g for global update:")
    LOG(ERROR, "  swazi vendor update -g <package>")
    rudisha
  }
  data target_root = is_global ? GLOBAL_ROOT : LOCAL_ROOT
  data package_specs = cli.args // Can be empty (update all) or ["math@2.0.0", "fmt"]

  jaribu {
    data manifest = is_global ? load_global_manifest() : load_and_parse_manifestfile(target_root)

    kama !manifest.vendor {
      LOG(INFO, "No packages to update")
      rudisha
    }

    data specs_to_update = []

    kama package_specs.empty() {
      // Update all packages
      LOG(INFO, "Updating all packages...")
      kwa kila (name, range) ktk manifest.vendor {
        specs_to_update.push(name + "@" + range)
      }
    } sivyo {
      // Update specific packages
      kwa kila spec ktk package_specs {
        data parsed = parse_spec(spec)

        kama !manifest.vendor[parsed.name] {
          LOG(WARN, parsed.name + " is not in manifest, skipping")
          endelea
        }

        // Update manifest with new range if specified
        kama spec.indexOf("@") > 0 {
          manifest.vendor[parsed.name] = parsed.range
          LOG(INFO, "Updated " + parsed.name + " to " + parsed.range + " in manifest")
        }

        specs_to_update.push(parsed.name + "@" + manifest.vendor[parsed.name])
      }

      // Save manifest if we changed version ranges
      kama is_global {
        save_global_manifest(manifest)
      } sivyo {
        data manifest_path = path.resolve(target_root, "swazi.json")
        fs.writeFile(manifest_path, json.stringify(manifest, null, 2))
      }
    }

    kama specs_to_update.empty() {
      LOG(INFO, "Nothing to update")
      rudisha
    }

    // Force re-resolution by removing lockfile
    data lock_path = is_global ?
      path.resolve(GLOBAL_ROOT, "swazi.lock") :
      path.resolve(target_root, "swazi.lock")

    kama fs.exists(lock_path) {
      fs.remove(lock_path)
      LOG(INFO, "Removed old lockfile, re-resolving...")
    }

    // Re-resolve and install
    LOG(INFO, "Resolving updated dependencies...")
    data graph = resolve_all(specs_to_update, target_root)

    data new_hash = hash_manifest(manifest)
    data lockdata = create_lockfile(graph, target_root, new_hash)

    download_packages(lockdata, target_root)
    extract_packages(lockdata)
    link_dependencies(lockdata, target_root, is_global)

    LOG(null, "✔ Update complete!")

  } makosa error {
    LOG(ERROR, "Update failed: " + error)
    tupa error
  }
}
kazi list_packages(cli) {
  data is_global = cli.flags.global au sikweli

  kama is_global {
    // List global packages
    data manifest = load_global_manifest()
    chapisha "Global packages:"

    kama !manifest.vendor au Object.keys(manifest.vendor).empty() {
      chapisha "  No global packages installed"
      rudisha
    }

    data lockdata = load_lockfile(GLOBAL_ROOT)

    kwa kila (name, version_range) ktk manifest.vendor {
      data installed_version = null

      // Get actual installed version from lockfile
      kama lockdata {
        kwa kila (pkg_key, info) ktk lockdata.packages {
          kama info.name == name {
            installed_version = info.version
            simama
          }
        }
      }

      kama installed_version {
        chapisha ("  -", name + "@" + installed_version, "(range:", version_range + ")")
      } sivyo {
        chapisha ("  -", name + "@" + version_range, "(not installed)")
      }
    }

  } sivyo {
    // List local packages
    kama !LOCAL_ROOT {
      LOG(ERROR, "Not in a project directory.")
      LOG(ERROR, "Use -g to list global packages: swazi vendor list -g")
      rudisha
    }

    data manifest = load_and_parse_manifestfile(LOCAL_ROOT)
    chapisha "Project dependencies:"

    kama !manifest.vendor au Object.keys(manifest.vendor).empty() {
      chapisha "  No dependencies"
      rudisha
    }

    data lockdata = load_lockfile(LOCAL_ROOT)

    kwa kila (name, version_range) ktk manifest.vendor {
      data installed_version = null

      kama lockdata {
        kwa kila (pkg_key, info) ktk lockdata.packages {
          kama info.name == name {
            installed_version = info.version
            simama
          }
        }
      }

      kama installed_version {
        chapisha ("  -", name + "@" + installed_version, "(range:", version_range + ")")
      } sivyo {
        chapisha ("  -", name + "@" + version_range, "(not installed)")
      }
    }
  }
  chapisha("")
}

// ========================================
// Global installation helpers
// ========================================
data &(
  get_globals_dir = () => path.resolve(GLOBAL_ROOT, "globals"),
  get_global_manifest_path = () => path.resolve(GLOBAL_ROOT, "global-manifest.json"),
)

kazi load_global_manifest() {
  data manifest_path = get_global_manifest_path()

  kama !fs.exists(manifest_path) {
    rudisha {
      vendor: {}
    }
  }

  jaribu {
    data content = fs.readFile(manifest_path, {
      encoding: "utf8"
    })
    rudisha json.parse(content)
  } makosa err {
    LOG(WARN, "Failed to read global manifest: " + err)
    rudisha {
      vendor: {}
    }
  }
}

kazi save_global_manifest(manifest) {
  data manifest_path = get_global_manifest_path()
  fs.writeFile(manifest_path, json.stringify(manifest, null, 2))
}

kazi create_bin_shim(bin_name, script_path, globals_dir) {
  data shim_path = path.resolve(globals_dir, bin_name)

  // Create a shell wrapper script that executes the actual script
  data shim_content = "#!/bin/sh\n" +
  "# Auto-generated shim for " + bin_name + "\n" +
  "exec swazi \"" + script_path + "\" \"$@\"\n"

  fs.writeFile(shim_path, shim_content)

  // Make executable (you'll need to implement this in your fs module)
  fs.chmod(shim_path, 0o755)

  LOG(INFO, "✔ Created shim: " + bin_name)
}

kazi remove_bin_shim(bin_name, globals_dir) {
  data shim_path = path.resolve(globals_dir, bin_name)

  kama fs.exists(shim_path) {
    fs.remove(shim_path)
    LOG(INFO, "✔ Removed shim: " + bin_name)
  }
}

kazi install_global_bins(pkg_name, pkg_version, globals_dir) {
  data vendor_dir = path.resolve(GLOBAL_ROOT, "vendor")
  data pkg_path = path.resolve(vendor_dir, pkg_name, pkg_version)
  data manifest_path = path.resolve(pkg_path, "swazi.json")

  kama !fs.exists(manifest_path) {
    LOG(WARN, "No manifest found for " + pkg_name + "@" + pkg_version)
    rudisha
  }

  jaribu {
    data content = fs.readFile(manifest_path, {
      encoding: "utf8"
    })
    data manifest = json.parse(content)

    kama !manifest.bin {
      LOG(HINT, "Package " + pkg_name + " has no bin scripts")
      rudisha
    }

    // manifest.bin can be:
    // 1. String: { "bin": "cli.swz" } -> bin name = package name
    // 2. Object: { "bin": { "mycli": "bin/cli.swz", "other": "bin/other.swz" } }

    kama ainaya manifest.bin == ainaya "" {
      // Single bin, name = package name
      data script_path = path.resolve(pkg_path, manifest.bin)
      create_bin_shim(pkg_name, script_path, globals_dir)
    } sivyo {
      // Multiple bins
      kwa kila (bin_name, script_rel) ktk manifest.bin {
        data script_path = path.resolve(pkg_path, script_rel)
        create_bin_shim(bin_name, script_path, globals_dir)
      }
    }

  } makosa err {
    LOG(ERROR, "Failed to install bins for " + pkg_name + ": " + err)
  }
}

kazi uninstall_global_bins(pkg_name, pkg_version, globals_dir) {
  data vendor_dir = path.resolve(GLOBAL_ROOT, "vendor")
  data pkg_path = path.resolve(vendor_dir, pkg_name, pkg_version)
  data manifest_path = path.resolve(pkg_path, "swazi.json")

  kama !fs.exists(manifest_path) {
    rudisha
  }

  jaribu {
    data content = fs.readFile(manifest_path, {
      encoding: "utf8"
    })
    data manifest = json.parse(content)

    kama !manifest.bin {
      rudisha
    }

    kama ainaya manifest.bin == ainaya "" {
      remove_bin_shim(pkg_name, globals_dir)
    } sivyo {
      kwa kila (bin_name, script_rel) ktk manifest.bin {
        remove_bin_shim(bin_name, globals_dir)
      }
    }

  } makosa err {
    LOG(ERROR, "Failed to uninstall bins for " + pkg_name + ": " + err)
  }
}

// ========================================
// Setup command - Initialize global store and configure PATH
// ========================================
kazi mango_setup(cli) {
  LOG(INFO, "Setting up Swazi package manager...")

  jaribu {
    // STEP 1: Create directory structure
    LOG(INFO, "Creating global directories...")

    data directories = [
      GLOBAL_ROOT,
      path.resolve(GLOBAL_ROOT, "cache"),
      path.resolve(GLOBAL_ROOT, "vendor"),
      get_globals_dir()
    ]

    kwa kila dir ktk directories {
      kama !fs.exists(dir) {
        fs.mkdir(dir, {
          recursive: kweli
        })
        LOG(INFO, "  ✔ Created: " + dir)
      } sivyo {
        LOG(HINT, "  ✓ Exists: " + dir)
      }
    }

    // STEP 2: Initialize global manifest if it doesn't exist
    data global_manifest_path = get_global_manifest_path()
    kama !fs.exists(global_manifest_path) {
      data initial_manifest = {
        vendor: {}
      }
      fs.writeFile(global_manifest_path, json.stringify(initial_manifest, null, 2))
      LOG(INFO, "  ✔ Created global manifest")
    } sivyo {
      LOG(HINT, "  ✓ Global manifest exists")
    }

    // STEP 3: Detect platform and provide PATH setup instructions
    data platform = os.platform()
    data globals_dir = get_globals_dir()
    data current_path = process.getEnv("PATH") au ""
    data path_delimiter = path.delimiter // : on Unix, ; on Windows

    LOG(null, "\n" + "=".rudia(50))
    LOG(null, "Setup complete!")
    LOG(null, "=".rudia(50))

    // Check if globals directory is already in PATH
    data is_in_path = current_path.split(path_delimiter).kuna(globals_dir)

    kama is_in_path {
      LOG(null, "\n✔ The globals directory is already in your PATH")
      LOG(null, "  " + globals_dir)
    } sivyo {
      LOG(null, "\n" + chalk.bold.yellow("⚠ ") + "IMPORTANT: Add Swazi globals to your PATH")
      LOG(null, "\nGlobals directory: " + globals_dir)

      // Platform-specific instructions
      kama platform == "linux" au platform == "macos" {
        LOG(null, "\nFor bash, add this to ~/.bashrc or ~/.bash_profile:")
        LOG(null, "  export PATH=\"" + globals_dir + ":$PATH\"")

        LOG(null, "\nFor zsh, add this to ~/.zshrc:")
        LOG(null, "  export PATH=\"" + globals_dir + ":$PATH\"")

        LOG(null, "\nFor fish, add this to ~/.config/fish/config.fish:")
        LOG(null, "  set -gx PATH " + globals_dir + " $PATH")

        LOG(null, "\nThen reload your shell:")
        LOG(null, "  source ~/.bashrc  # or source ~/.zshrc")

      } sivyo kama platform == "win32" {
        LOG(null, "\nFor Windows, you have two options:")
        LOG(null, "\n1. Using PowerShell (recommended):")
        LOG(null, "   Run PowerShell as Administrator and execute:")
        LOG(null, "   [Environment]::SetEnvironmentVariable(")
        LOG(null, "     'Path',")
        LOG(null, "     [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + '" + globals_dir + "',")
        LOG(null, "     'User'")
        LOG(null, "   )")

        LOG(null, "\n2. Using GUI:")
        LOG(null, "   - Press Win + X and select 'System'")
        LOG(null, "   - Click 'Advanced system settings'")
        LOG(null, "   - Click 'Environment Variables'")
        LOG(null, "   - Under 'User variables', select 'Path' and click 'Edit'")
        LOG(null, "   - Click 'New' and add: " + globals_dir)
        LOG(null, "   - Click 'OK' on all dialogs")
        LOG(null, "   - Restart your terminal/command prompt")

      } sivyo {
        LOG(null, "\nManually add this directory to your PATH:")
        LOG(null, "  " + globals_dir)
      }
    }

    // STEP 4: Summary and next steps
    LOG(null, "\n" + "=".rudia(50))
    LOG(null, "Directory structure:")
    LOG(null, "  " + GLOBAL_ROOT)
    LOG(null, "  ├── cache/          (downloaded tarballs)")
    LOG(null, "  ├── vendor/         (extracted packages)")
    LOG(null, "  ├── globals/        (bin shims - add to PATH)")
    LOG(null, "  └── global-manifest.json")
    LOG(null, "=".rudia(50))

    LOG(null, "\nNext steps:")
    kama !is_in_path {
      LOG(null, "  1. Add globals directory to PATH (see instructions above)")
      LOG(null, "  2. Restart your terminal")
      LOG(null, "  3. Install packages: swazi vendor install -g <package>")
    } sivyo {
      LOG(null, "  1. Install packages: swazi vendor install -g <package>")
      LOG(null, "  2. Or initialize a project: swazi init")
    }

    LOG(null, "\nRegistry URL: " + REGISTRY_URL)
    LOG(null, "")

  } makosa error {
    LOG(ERROR, "Setup failed: " + error)
    tupa error
  }
}

// ========================================
// Check if Swazi is properly set up
// ========================================
kazi check_setup() {
  data is_setup = kweli

  // Check if global directories exist
  data required_dirs = [
    GLOBAL_ROOT,
    path.resolve(GLOBAL_ROOT, "cache"),
    path.resolve(GLOBAL_ROOT, "vendor"),
    get_globals_dir()
  ]

  kwa kila dir ktk required_dirs {
    kama !fs.exists(dir) {
      is_setup = sikweli
      simama
    }
  }

  // Check if global manifest exists
  kama !fs.exists(get_global_manifest_path()) {
    is_setup = sikweli
  }

  rudisha is_setup
}

// Call this at the start of install/unlink/update commands
kazi ensure_setup() {
  kama !check_setup() {
    LOG(ERROR, "Swazi is not set up. Please run: swazi setup")
    tupa "Setup required"
  }
}

// ========================================
// Search packages command
// ========================================
kazi search_packages(cli) {
  data query = cli.args[0]
  data limit = cli.flags.limit au 20
  data offset = cli.flags.offset au 0

  kama !query {
    LOG(ERROR, "Please provide a search query")
    LOG(null, "Usage: swazi vendor search <query>")
    LOG(null, "       swazi vendor search <query> --limit 10")
    rudisha
  }

  jaribu {
    LOG(INFO, "Searching for '" + query + "'...")

    // Build search URL with query parameters
    data search_url = REGISTRY_URL + "/api/search?q=" + URL.encodeURIComponent(query) +
    "&limit=" + limit.str() +
    "&offset=" + offset.str()

    data response = http.get(search_url, {
      headers: {
        "Accept": "application/json"
      }
    })

    data results = json.parse(response)

    kama !results.success {
      LOG(ERROR, "Search failed: " + (results.error au "Unknown error"))
      rudisha
    }

    kama results.results.empty() {
      LOG(INFO, "No packages found matching '" + query + "'")
      LOG(HINT, "Try a different search term or browse all packages at " + REGISTRY_URL)
      rudisha
    }

    // Display results
    chapisha ""
    chapisha chalk.bold("Search Results for: ") + chalk.cyan(query)
    chapisha chalk.dim("Found " + results.total + " package(s), showing " + results.results.size)
    chapisha "=".rudia(50)
    chapisha ""

    kwa kila pkg ktk results.results {
      // Package name and version
      chapisha chalk.bold.green(pkg.name) + " " + chalk.dim("v" + pkg.version)

      // Author
      chapisha "  " + chalk.dim("by ") + chalk.yellow(pkg.author)

      // Description from manifest (if available)
      kama pkg.manifest na pkg.manifest.description {
        data description = pkg.manifest.description
        // Truncate long descriptions
        kama description.size > 80 {
          description = description.substr(0, 77) + "..."
        }
        chapisha "  " + description
      }

      // Downloads
      chapisha "  " + chalk.dim("↓ ") + pkg.downloads + chalk.dim(" downloads")

      // Install command
      chapisha "  " + chalk.dim("Install: ") + chalk.cyan("swazi vendor install " + pkg.name)

      chapisha ""
    }

    // Pagination info
    kama results.total > (offset + limit) {
      data next_offset = offset + limit
      chapisha chalk.dim("More results available. Use: ") +
      chalk.cyan("swazi vendor search \"" + query + "\" --offset " + next_offset)
      chapisha ""
    }

  } makosa error {
    LOG(ERROR, "Search failed: " + error)
    LOG(HINT, "Make sure the registry is accessible at " + REGISTRY_URL)
  }
}

// ========================================
// Info command - Get detailed package information
// ========================================
kazi info_package(cli) {
  data pkg_name = cli.args[0]

  kama !pkg_name {
    LOG(ERROR, "Please provide a package name")
    LOG(INFO, "Usage: swazi vendor info <package-name>")
    rudisha
  }

  jaribu {
    LOG(INFO, "Fetching info for " + pkg_name + "...")

    // Fetch package metadata
    data url = REGISTRY_URL + "/api/packages/" + pkg_name

    data response = http.get(url, {
      headers: {
        "Accept": "application/json"
      }
    })

    data metadata = json.parse(response)

    kama !metadata.success {
      LOG(ERROR, "Package not found: " + pkg_name)
      LOG(HINT, "Search for packages: swazi vendor search <query>")
      rudisha
    }

    // Get latest version info
    data latest = metadata.versions[metadata.latestVersion]

    // Display package info
    chapisha ""
    chapisha chalk.bold.green(metadata.name) + " " + chalk.dim("v" + metadata.latestVersion)
    chapisha "=".rudia(50)

    // Description
    kama latest.manifest.description {
      chapisha ""
      chapisha chalk.bold("Description:")
      chapisha "  " + latest.manifest.description
    }

    // Author
    chapisha ""
    chapisha chalk.bold("Author: ") + chalk.yellow(latest.author)

    // License
    kama latest.manifest.license {
      chapisha chalk.bold("License: ") + latest.manifest.license
    }

    // Homepage/Repository
    kama latest.manifest.homepage {
      chapisha chalk.bold("Homepage: ") + chalk.cyan(latest.manifest.homepage)
    }

    kama latest.manifest.repository {
      data repo = latest.manifest.repository
      kama ainaya repo == ainaya "" {
        chapisha chalk.bold("Repository: ") + chalk.cyan(repo)
      } sivyo kama repo.url {
        chapisha chalk.bold("Repository: ") + chalk.cyan(repo.url)
      }
    }

    // Stats
    chapisha ""
    chapisha chalk.bold("Statistics:")
    chapisha "  Total downloads: " + chalk.cyan(metadata.totalDownloads.toStr())
    chapisha "  Available versions: " + chalk.cyan(Object.keys(metadata.versions).size.toStr())

    // Dependencies
    kama latest.manifest.vendor na !Object.keys(latest.manifest.vendor).empty() {
      chapisha ""
      chapisha chalk.bold("Dependencies:")
      kwa kila (dep_name, dep_version) ktk latest.manifest.vendor {
        chapisha "  • " + dep_name + chalk.dim("@" + dep_version)
      }
    } sivyo {
      chapisha ""
      chapisha chalk.dim("No dependencies")
    }

    // Available versions
    chapisha ""
    chapisha chalk.bold("Versions:")
    data version_list = Object.keys(metadata.versions).slice(0, 10)
    kwa kila v ktk version_list {
      data version_info = metadata.versions[v]
      data is_latest = v == metadata.latestVersion ? chalk.green(" (latest)") : ""
      chapisha "  • " + v + is_latest + chalk.dim(" - " + version_info.createdAt.substr(0, 10))
    }

    kama Object.keys(metadata.versions).size > 10 {
      chapisha chalk.dim("  ... and " + (Object.keys(metadata.versions).size - 10) + " more")
    }

    // Install command
    chapisha ""
    chapisha chalk.bold("Install:")
    chapisha "  Local:  " + chalk.cyan("swazi vendor install " + pkg_name)
    chapisha "  Global: " + chalk.cyan("swazi vendor install -g " + pkg_name)
    chapisha ""

  } makosa error {
    LOG(ERROR, "Failed to fetch package info: " + error)
    LOG(HINT, "Make sure the registry is accessible at " + REGISTRY_URL)
  }
}

// ========================================
// Browse command - List popular/recent packages
// ========================================
kazi browse_packages(cli) {
  data sort = cli.flags.sort || "recent" // recent, downloads
  data limit = cli.flags.limit || 20

  jaribu {
    data title = ""

    kama sort == "recent" {
      title = "Recently Published Packages"
      LOG(INFO, "Fetching recent packages...")
    } sivyo kama sort == "popular" {
      title = "Popular Packages"
      LOG(INFO, "Fetching popular packages...")
    } sivyo {
      LOG(ERROR, "Invalid sort option. Use: recent or popular")
      rudisha
    }

    // Use search with empty query to get all packages
    data url = REGISTRY_URL + "/api/search?q=%20&limit=" + limit.str()

    data response = http.get(url, {
      headers: {
        "Accept": "application/json"
      }
    })

    data results = json.parse(response)

    kama !results.success au results.results.empty() {
      LOG(INFO, "No packages available")
      rudisha
    }

    // Sort results
    data packages = results.results

    kama sort == "popular" {
      packages = packages.sort((a, b) => b.downloads - a.downloads)
    }

    // Display results
    chapisha ""
    chapisha chalk.bold(title)
    chapisha "=".rudia(50)
    chapisha ""

    kwa kila (pkg, idx) ktk packages {
      data rank = " ".rudia(2) + (idx + 1).toStr()

      chapisha chalk.dim(rank + ".") + " " + chalk.bold.green(pkg.name) + " " +
      chalk.dim("v" + pkg.version)

      chapisha "    " + chalk.dim("by ") + chalk.yellow(pkg.author) +
      chalk.dim(" • ↓ " + pkg.downloads)

      kama pkg.manifest.description {
        data desc = pkg.manifest.description
        kama desc.size > 70 {
          desc = desc.substr(0, 67) + "..."
        }
        chapisha "    " + desc
      }

      chapisha ""
    }

  } makosa error {
    LOG(ERROR, "Failed to browse packages: " + error)
    LOG(HINT, "Make sure the registry is accessible at " + REGISTRY_URL)
  }
}


// ========================================
// Build system helpers
// ========================================

kazi async detect_build_system() {
  // Detect available build tools on the system
  data tools = {
    cmake: sikweli,
    make: sikweli,
    gcc: sikweli,
    gpp: sikweli,
    // g++
    clang: sikweli,
    clangpp: sikweli,
    // clang++
    ninja: sikweli
  }

  // Helper to check if a tool exists
  data check_tool = async (cmd) => {
    jaribu {
      data result = await subprocess.exec(cmd + " --version")
      rudisha result.code == 0 na result.stdout.size > 0
    } makosa _ {
      rudisha sikweli
    }
  }

  // Check all tools
  tools.cmake = await check_tool("cmake")
  tools.make = await check_tool("make")
  tools.gcc = await check_tool("gcc")
  tools.gpp = await check_tool("g++")
  tools.clang = await check_tool("clang")
  tools.clangpp = await check_tool("clang++")
  tools.ninja = await check_tool("ninja")

  rudisha tools
}

kazi async get_tool_version(tool_name) {
  jaribu {
    data result = await subprocess.exec(tool_name + " --version")

    kama result.code != 0 {
      rudisha null
    }

    data version_output = result.stdout

    // Extract version number (usually in format X.Y.Z)
    data version_match = (/(\d+)\.(\d+)\.(\d+)/).match(version_output)

    kama version_match {
      rudisha {
        major: parseInt(version_match[1]),
        minor: parseInt(version_match[2]),
        patch: parseInt(version_match[3]),
        full: version_match[0]
      }
    }

    rudisha null
  } makosa _ {
    rudisha null
  }
}

kazi compare_version_requirement(current, required) {
  // Compare version: required format ">=3.10" or "3.10" (exact)
  kama !current au !required {
    rudisha kweli
  }

  // Parse requirement
  data operator = ">="
  data req_version = required

  kama required.startsWith(">=") {
    operator = ">="
    req_version = required.substr(2).trim()
  } sivyo kama required.startsWith("<=") {
    operator = "<="
    req_version = required.substr(2).trim()
  } sivyo kama required.startsWith(">") {
    operator = ">"
    req_version = required.substr(1).trim()
  } sivyo kama required.startsWith("<") {
    operator = "<"
    req_version = required.substr(1).trim()
  } sivyo kama required.startsWith("==") {
    operator = "=="
    req_version = required.substr(2).trim()
  }

  // Parse required version
  data req_parts = req_version.split(".")
  data req_major = parseInt(req_parts[0] au "0")
  data req_minor = parseInt(req_parts[1] au "0")
  data req_patch = parseInt(req_parts[2] au "0")

  // Compare
  kama operator == ">=" {
    kama current.major > req_major =>> rudisha kweli
    kama current.major < req_major =>> rudisha sikweli
    kama current.minor > req_minor =>> rudisha kweli
    kama current.minor < req_minor =>> rudisha sikweli
    rudisha current.patch >= req_patch
  }

  kama operator == "<=" {
    kama current.major < req_major =>> rudisha kweli
    kama current.major > req_major =>> rudisha sikweli
    kama current.minor < req_minor =>> rudisha kweli
    kama current.minor > req_minor =>> rudisha sikweli
    rudisha current.patch <= req_patch
  }

  kama operator == ">" {
    kama current.major > req_major =>> rudisha kweli
    kama current.major < req_major =>> rudisha sikweli
    kama current.minor > req_minor =>> rudisha kweli
    kama current.minor < req_minor =>> rudisha sikweli
    rudisha current.patch > req_patch
  }

  kama operator == "<" {
    kama current.major < req_major =>> rudisha kweli
    kama current.major > req_major =>> rudisha sikweli
    kama current.minor < req_minor =>> rudisha kweli
    kama current.minor > req_minor =>> rudisha sikweli
    rudisha current.patch < req_patch
  }

  kama operator == "==" {
    rudisha (current.major == req_major na
      current.minor == req_minor na
      current.patch == req_patch)
  }

  rudisha kweli
}

kazi async check_build_requirements(manifest) {
  // Check if manifest has build requirements
  kama !manifest.build {
    rudisha {
      satisfied: kweli,
      missing: []
    }
  }

  data build_config = manifest.build
  data requirements = build_config.requires au {}

  kama Object.keys(requirements).empty() {
    rudisha {
      satisfied: kweli,
      missing: []
    }
  }

  LOG(INFO, "Checking build requirements...")

  data missing = []
  data available_tools = await detect_build_system()

  // Check each requirement
  kwa kila (tool, version_req) ktk requirements {
    // Normalize tool name
    data tool_cmd = tool
    kama tool == "g++" =>> tool_cmd = "gpp"
    kama tool == "clang++" =>> tool_cmd = "clangpp"

    // Check if tool is available
    kama !available_tools[tool_cmd] {
      missing.push( {
        tool: tool,
        required: version_req,
        reason: "not installed"
      })
      endelea
    }

    // Check version if specified
    kama version_req na version_req != "*" {
      data current_version = await get_tool_version(tool)

      kama !current_version {
        missing.push( {
          tool: tool,
          required: version_req,
          reason: "version unknown"
        })
        endelea
      }

      kama !compare_version_requirement(current_version, version_req) {
        missing.push( {
          tool: tool,
          required: version_req,
          current: current_version.full,
          reason: "version mismatch"
        })
      }
    }
  }

  rudisha {
    satisfied: missing.empty(),
    missing: missing,
    available: available_tools
  }
}

kazi async build_native_addon(pkg_name, pkg_version, pkg_path, build_config) {
  LOG(INFO, "Building native addon for " + pkg_name + "@" + pkg_version + "...")

  data build_dir = build_config.buildDir au "addons"
  data build_path = path.resolve(pkg_path, build_dir)

  // Create build directory if it doesn't exist
  kama !fs.exists(build_path) {
    fs.mkdir(build_path, {
      recursive: kweli
    })
  }

  // Determine build system
  data cmake_file = path.resolve(pkg_path, "CMakeLists.txt")
  data makefile = path.resolve(pkg_path, "Makefile")

  jaribu {
    kama fs.exists(cmake_file) {
      // Use CMake
      LOG(INFO, "  Using CMake build system...")

      // Configure
      data generator = build_config.generator au "Unix Makefiles"
      data cmake_args = build_config.cmakeArgs au []

      data configure_cmd = "cmake -S \"" + pkg_path + "\" -B \"" + build_path + "\" -G \"" + generator + "\""

      kwa kila arg ktk cmake_args {
        configure_cmd += " " + arg
      }

      LOG(HINT, "  Configuring: " + configure_cmd)
      data configure_result = await subprocess.exec(configure_cmd)

      kama configure_result.code != 0 {
        LOG(ERROR, "  CMake stderr: " + configure_result.stderr)
        tupa "CMake configuration failed"
      }

      // Build
      data build_cmd = "cmake --build \"" + build_path + "\""

      kama build_config.buildArgs {
        kwa kila arg ktk build_config.buildArgs {
          build_cmd += " " + arg
        }
      }

      LOG(HINT, "  Building: " + build_cmd)
      data build_result = await subprocess.exec(build_cmd)

      kama build_result.code != 0 {
        LOG(ERROR, "  Build stderr: " + build_result.stderr)
        tupa "CMake build failed"
      }

      // Install (optional)
      kama build_config.install {
        data install_cmd = "cmake --install \"" + build_path + "\""
        LOG(HINT, "  Installing: " + install_cmd)
        await subprocess.exec(install_cmd)
      }

      LOG(INFO, "✔ Native addon built successfully")

    } sivyo kama fs.exists(makefile) {
      // Use Make
      LOG(INFO, "  Using Make build system...")

      data make_cmd = "make -C \"" + pkg_path + "\""

      kama build_config.makeTarget {
        make_cmd += " " + build_config.makeTarget
      }

      LOG(HINT, "  Building: " + make_cmd)
      data make_result = await subprocess.exec(make_cmd)

      kama make_result.code != 0 {
        LOG(ERROR, "  Make stderr: " + make_result.stderr)
        tupa "Make build failed"
      }

      LOG(INFO, "✔ Native addon built successfully")

    } sivyo {
      LOG(WARN, "  No build system detected (CMakeLists.txt or Makefile)")
      rudisha sikweli // Not an error, just skip
    }

    rudisha kweli

  } makosa err {
    LOG(ERROR, "  Build failed: " + err)
    rudisha sikweli
  }
}

// ========================================
// Build cache helpers
// ========================================

// Build cache file format
kazi get_build_cache_path(pkg_path, build_config) {
  data build_dir = build_config.buildDir au "addons"
  rudisha path.resolve(pkg_path, build_dir, ".build-cache.json")
}

// Hash build configuration for change detection
kazi hash_build_config(build_config) {
  // Normalize build config (remove dynamic fields)
  data normalized = {
    buildDir: build_config.buildDir,
    requires: build_config.requires,
    generator: build_config.generator,
    cmakeArgs: build_config.cmakeArgs,
    buildArgs: build_config.buildArgs,
    makeTarget: build_config.makeTarget,
    sources: build_config.sources
  }

  data config_json = json.stringify(normalized)
  rudisha crypto.hash("sha256", config_json).toStr("hex")
}

// Hash source files for change detection
kazi async hash_source_files(pkg_path, build_config) {
  data source_files = []

  // Get sources from manifest or scan
  kama build_config.sources {
    source_files = build_config.sources
  } sivyo {
    // Scan for common C/C++ source files
    data extensions = [
      ".cpp",
      ".c",
      ".cc",
      ".h",
      ".hpp",
      ".cxx",
      ".hxx"]
    data all_files = fs.readdir(pkg_path, {
      recursive: kweli
    })

    kwa kila file ktk all_files {
      data ext = path.extname(file)
      kama extensions.kuna(ext) {
        source_files.push(file)
      }
    }
  }

  // Sort for consistent hashing
  source_files = source_files.sort()

  // Hash all sources in order
  data hasher = crypto.createHash("sha256")

  kwa kila src_file ktk source_files {
    data file_path = path.resolve(pkg_path, src_file)

    kama fs.exists(file_path) {
      data content = fs.readFile(file_path, {
        encoding: "binary"
      })
      hasher.update(content)
      hasher.update(src_file) // Include filename for uniqueness
    }
  }

  rudisha hasher.finalize().toStr("hex")
}

// Detect built artifacts in build directory
kazi detect_build_artifacts(build_path) {
  data artifacts = []
  data extensions = [
    ".so",
    ".a",
    ".dylib",
    ".dll",
    ".swazi",
    ".lib"
  ]

  kama !fs.exists(build_path) {
    rudisha artifacts
  }

  // Use recursive readdir
  data files = fs.readdir(build_path, {
    recursive: kweli,
    absolute: kweli,
    withFileTypes: kweli,
    filter: (name) => {
      data ext = path.extname(name)
      rudisha extensions.kuna(ext)
    }
  })

  kwa kila file ktk files {
    jaribu {
      // Hash the artifact
      data content = fs.readFile(file.name, {
        encoding: "binary"
      })
      data hash = crypto.hash("sha256", content).toStr("hex")

      // Store relative path
      data relative = path.relative(build_path, file.name)

      artifacts.push({
        path: relative,
        hash: hash,
        size: file.size
      })
    } makosa err {
      LOG(WARN, "Failed to hash artifact " + relative + ": " + err)
    }
  }

  rudisha artifacts
}

// Check if build cache is valid
kazi async check_build_cache(pkg_path, build_config, force_build) {
  kama force_build {
    rudisha {
      valid: sikweli,
      reason: "force rebuild requested"
    }
  }

  data cache_path = get_build_cache_path(pkg_path, build_config)

  kama !fs.exists(cache_path) {
    rudisha {
      valid: sikweli,
      reason: "no cache file"
    }
  }

  jaribu {
    data cache_content = fs.readFile(cache_path, {
      encoding: "utf8"
    })
    data cache = json.parse(cache_content)

    // Check build config hash
    data current_config_hash = hash_build_config(build_config)
    kama cache.buildConfigHash != current_config_hash {
      rudisha {
        valid: sikweli,
        reason: "build configuration changed"
      }
    }

    // Check source files hash
    data current_source_hash = await hash_source_files(pkg_path, build_config)
    kama cache.sourceFilesHash != current_source_hash {
      rudisha {
        valid: sikweli,
        reason: "source files changed"
      }
    }

    // Verify all artifacts exist and match hash
    data build_dir = build_config.buildDir au "addons"
    data build_path = path.resolve(pkg_path, build_dir)

    kwa kila target ktk cache.targets {
      data target_path = path.resolve(build_path, target.path)

      kama !fs.exists(target_path) {
        rudisha {
          valid: sikweli,
          reason: "artifact missing: " + target.path
        }
      }

      // Verify integrity
      data content = fs.readFile(target_path, {
        encoding: "binary"
      })
      data current_hash = crypto.hash("sha256", content).toStr("hex")

      kama current_hash != target.hash {
        rudisha {
          valid: sikweli,
          reason: "artifact corrupted: " + target.path
        }
      }
    }

    // All checks passed
    rudisha {
      valid: kweli
    }

  } makosa err {
    rudisha {
      valid: sikweli,
      reason: "cache read error: " + err
    }
  }
}

// Save build cache after successful build
kazi async save_build_cache(pkg_path, build_config) {
  data build_dir = build_config.buildDir au "addons"
  data build_path = path.resolve(pkg_path, build_dir)

  // Detect built artifacts
  data artifacts = detect_build_artifacts(build_path)

  kama artifacts.empty() {
    LOG(WARN, "No build artifacts detected, skipping cache creation")
    rudisha
  }

  // Get tool versions
  data tool_versions = {}
  data tools = ["cmake",
    "gcc",
    "g++",
    "clang",
    "clang++",
    "make"]

  kwa kila tool ktk tools {
    data version = await get_tool_version(tool)
    kama version {
      tool_versions[tool] = version.full
    }
  }

  // Create cache object
  data cache = {
    version: 1,
    timestamp: datetime.now().str(),
    buildConfigHash: hash_build_config(build_config),
    sourceFilesHash: await hash_source_files(pkg_path, build_config),
    toolVersions: tool_versions,
    targets: artifacts
  }

  // Write cache file
  data cache_path = get_build_cache_path(pkg_path, build_config)
  fs.writeFile(cache_path, json.stringify(cache, null, 2))

  LOG(HINT, "  Build cache saved with " + artifacts.size + " artifact(s)")
}

// Extract packages requiring builds from lockfile
kazi extract_build_required_from_lockfile(lockdata) {
  data vendor_dir = path.resolve(GLOBAL_ROOT, "vendor")
  data build_required = []

  kwa kila (pkg_key, info) ktk lockdata.packages {
    data pkg_path = path.resolve(vendor_dir, info.name, info.version)
    data manifest_path = path.resolve(pkg_path, "swazi.json")

    kama fs.exists(manifest_path) {
      jaribu {
        data content = fs.readFile(manifest_path, {
          encoding: "utf8"
        })
        data manifest = json.parse(content)

        kama manifest.build {
          build_required.push(pkg_key)
        }
      } makosa _ {
        // Skip if manifest unreadable
      }
    }
  }

  rudisha build_required
}

ruhusu {
  install_package,
  unlink_package,
  update_package,
  list_packages,
  mango_setup,
  search_packages,
  info_package,
  browse_packages
}