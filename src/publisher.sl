// src/package-publisher.sl
tumia process
tumia fs
tumia path
tumia {
  get_project_root,
  load_and_parse_manifestfile,
  is_readme_available_at_root,
  load_readme,
  package_name_is_valid,
  package_version_is_valid,
  package_entry_is_valid,
  scan_package_files,
  create_artifact,
  compute_hash,
  uploading_to_registry,
  validate_bin,
  validate_dependencies
} kutoka "utils/helpers"
tumia "registry.sl"

tumia "utils/logger.swz"


kazi publisher(cmd) {
  data cwd = process.cwd()
  data root = get_project_root(cwd)
  
  kama cmd.flags.dryrun {
    chapisha("[DRY-RUN]")
  }
  LOG(INFO, "Packaging and publish swazi packages")

  data manifest = load_and_parse_manifestfile(root);
  
  kama (!manifest.type au (manifest.type != "package" na manifest.type != "library")) {
    tupa "Project type must be defined and be either 'package' or 'library'."
  }
  
  kama !manifest.name {
    tupa "No package name specified in swazi.json!"
  }
  kama !package_name_is_valid(manifest.name) {
    tupa "Invalid package name: " + manifest.name
  }
  kama !manifest.version {
    tupa "No package version specified in swazi.json!"
  }
  kama !package_version_is_valid(manifest.version) {
    tupa "Invalid version"
  }
  kama !manifest.entry {
    tupa "No package entry specified in swazi.json!"
  }
  kama !package_entry_is_valid(manifest.entry, root) {
    tupa "Invalid package entry!"
  }
  // validate package docs/descreption the root README.md
  kama !manifest.description {
    kama !is_readme_available_at_root(root) {
      tupa "No valid package descreption or README.md"
    }
  }
  
  // validate vendor deps shapes
  kama manifest.vendor au manifest.devs {
    data deps = validate_dependencies(manifest)
    manifest.vendor = deps.vendor
    manifest.devs = deps.devs
  }
  
  // returns a path array to all files to be bundled in the artifact
  data paths = scan_package_files(root, manifest); 
  
  // check for executables
  kama manifest.bin {
    manifest.executables = validate_bin(root, manifest, paths)
  }
  data targz = `${manifest.name}-${manifest.version}.tar.gz`;
  manifest.tarball = targz
  
  // a [name]-[version].tar.gz binary
  data artifact = create_artifact(root, paths)
  LOG(INFO, "package artifact created 📦")
  LOG(INFO, "archive: " + targz)
  
  // SHA-256sum hash
  data artifact_hash = compute_hash(artifact)
  LOG(INFO, "checksum SHA-256:" + artifact_hash[0..20]+"...")
  
  kama !cmd.flags.dryrun {
    LOG(INFO, "Uploading...")
    uploading_to_registry(artifact, manifest, artifact_hash)
  }
}

kazi packaging(cmd) {
  data cwd = process.cwd()
  data root = get_project_root(cwd)
  
  kama cmd.flags.dryrun {
    chapisha("[DRY-RUN]")
  }
  LOG(INFO, "Packaging and publish swazi packages")

  data manifest = load_and_parse_manifestfile(root);
  
  kama (!manifest.type au (manifest.type != "package" na manifest.type != "library")) {
    tupa "Project type must be defined and be either 'package' or 'library'."
  }
  
  kama !manifest.name {
    tupa "No package name specified in swazi.json!"
  }
  kama !package_name_is_valid(manifest.name) {
    tupa "Invalid package name: " + manifest.name
  }
  kama !manifest.version {
    tupa "No package version specified in swazi.json!"
  }
  kama !package_version_is_valid(manifest.version) {
    tupa "Invalid version"
  }
  kama !manifest.entry {
    tupa "No package entry specified in swazi.json!"
  }
  kama !package_entry_is_valid(manifest.entry, root) {
    tupa "Invalid package entry!"
  }
  // validate package docs/descreption the root README.md
  kama !manifest.description {
    kama !is_readme_available_at_root(root) {
      tupa "No valid package descreption or README.md"
    }
  }
  
  // we should read some dependencies here but for now let us first skip it
  LOG(INFO, "dependencies resolution...")
  // dependencies resolution and creation of lockfile here but for now let us just skip it
  LOG(INFO, "✔ dependencies resolution complete")
  # data deps = resolve_dependencies(manifest.vendor)
  # create_lockfile(deps)
  
  // first since we do not have linters.. and this is not js such it needs to be build we jump to artifact generation
  // return a path array to all files to be bundled in the artifact
  data paths = scan_package_files(root, manifest);
  data targz = `${manifest.name}-${manifest.version}.tar.gz`;
  // a [name]-[version].tar.gz binary
  data artifact = create_artifact(root, paths)
  LOG(INFO, "package artifact created 📦")
  LOG(INFO, "archive name: " + targz);
  kama (!cmd.flags.dryrun) {
    LOG(INFO, "writting archive to disc");
    kama (fs.writeFile(path.resolve(root, targz), artifact)) {
    LOG(INFO, "✅️ Done!");
  }
  }
  
  // SHA-256sum hash
  data artifact_hash = compute_hash(artifact)
  LOG(INFO, "checksum SHA-256:" + artifact_hash[0..20]+"...")
  LOG(null, "✔ DONE! " + manifest.name + "@" + manifest.version)
}


ruhusu {
  publisher,
  packaging
}