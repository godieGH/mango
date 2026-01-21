#!/usr/bin/env swazi
tumia chalk kutoka "vendor:chalk"
tumia { parse } kutoka "src/parse_cli.sl"
tumia { publisher, packaging } kutoka "src/publisher.sl"
tumia { register_user, login_user } kutoka "src/registry.sl"

tumia { 
  install_package,
  unlink_package,
  update_package,
  list_packages,
  mango_setup,
  search_packages,
  info_package,
  browse_packages
} kutoka "src/packages.sl"
tumia { load_and_parse_manifestfile } kutoka "src/utils/helpers.swz"
data pkg = load_and_parse_manifestfile(__dir__)

kazi main() {
  // getting the cli arguments and call parse to parse them
  data cli = argv.slice(2)
  
  kama cli[0] == "--version" || cli[0] == "-v" {
    chapisha "mango " + pkg.version
    rudisha;
  }
  
  kama cli[0] == "--help" || cli[0] == "-h" {
    chapisha ""
    chapisha chalk.bold.cyan("Mango v" + pkg.version) + " - Swazi Package Manager"
    chapisha ""
    chapisha chalk.bold("Usage:") + " mango <command> [options]"
    chapisha ""
    chapisha chalk.bold("Commands:")
    chapisha "  " + chalk.green("setup") + "                   Initialize Mango global directories"
    chapisha "  " + chalk.green("install") + " [pkgs...]       Install packages from registry"
    chapisha "  " + chalk.green("unlink") + " <pkgs...>        Remove packages from project"
    chapisha "  " + chalk.green("update") + " [pkgs...]        Update packages to latest versions"
    chapisha "  " + chalk.green("list") + "                    List installed packages"
    chapisha "  " + chalk.green("search") + " <query>          Search for packages"
    chapisha "  " + chalk.green("info") + " <package>          Show package information"
    chapisha "  " + chalk.green("browse") + "                  Browse available packages"
    chapisha "  " + chalk.green("publish") + "                 Publish package to registry"
    chapisha "  " + chalk.green("pack") + "                    Create package tarball"
    chapisha "  " + chalk.green("register") + "                Create registry account"
    chapisha "  " + chalk.green("login") + "                   Log in to registry"
    chapisha ""
    chapisha chalk.bold("Options:")
    chapisha "  -v, --version           Show version number"
    chapisha "  -h, --help              Show this help message"
    chapisha ""
    chapisha "Run " + chalk.cyan("mango <command> --help") + " for command-specific help"
    chapisha ""
    rudisha;
  }
  
  // publish command
  fanya {
    data cmd = parse(cli, {
      help: ["--help", "-h", null, null],
      dryrun: ["--dry-run", null, null, null]
    })
    kama cmd.command == "publish" {
      kama cmd.flags.help {
        chapisha ""
        chapisha chalk.bold("mango publish") + " - Publish package to registry"
        chapisha ""
        chapisha chalk.bold("Usage:")
        chapisha "  mango publish [options]"
        chapisha ""
        chapisha chalk.bold("Options:")
        chapisha "  --dry-run    Test publish without uploading"
        chapisha "  -h, --help   Show this help"
        chapisha ""
        chapisha chalk.bold("Examples:")
        chapisha "  mango publish"
        chapisha "  mango publish --dry-run"
        chapisha ""
        rudisha;
      }
      publisher(cmd)
      rudisha;
    }
  }
  
  fanya {
    data cmd = parse(cli, {
      help: ["--help", "-h", null, null],
      dryrun: ["--dry-run", null, null, null]
    })
    kama cmd.command == "pack" {
      kama cmd.flags.help {
        chapisha ""
        chapisha chalk.bold("mango pack") + " - Create package tarball"
        chapisha ""
        chapisha chalk.bold("Usage:")
        chapisha "  mango pack [options]"
        chapisha ""
        chapisha chalk.bold("Options:")
        chapisha "  --dry-run    Test packing without creating file"
        chapisha "  -h, --help   Show this help"
        chapisha ""
        chapisha chalk.bold("Examples:")
        chapisha "  mango pack"
        chapisha "  mango pack --dry-run"
        chapisha ""
        rudisha;
      }
      packaging(cmd)
      rudisha;
    }
  }
  
  fanya {
    data cmd = parse(cli, {
      help: ["--help", "-h", null, null]
    })
    kama cmd.command == "register" {
      kama cmd.flags.help {
        chapisha ""
        chapisha chalk.bold("mango register") + " - Create registry account"
        chapisha ""
        chapisha chalk.bold("Usage:")
        chapisha "  mango register"
        chapisha ""
        chapisha chalk.bold("Description:")
        chapisha "  Interactive command to create a new account on the registry."
        chapisha "  You will be prompted for username, email, and password."
        chapisha ""
        chapisha chalk.bold("Example:")
        chapisha "  mango register"
        chapisha ""
        rudisha;
      }
      register_user(cmd)
      rudisha;
    }
  }
  
  fanya {
    data cmd = parse(cli, {
      help: ["--help", "-h", null, null]
    })
    kama cmd.command == "login" {
      kama cmd.flags.help {
        chapisha ""
        chapisha chalk.bold("mango login") + " - Log in to registry"
        chapisha ""
        chapisha chalk.bold("Usage:")
        chapisha "  mango login"
        chapisha ""
        chapisha chalk.bold("Description:")
        chapisha "  Interactive command to authenticate with the registry."
        chapisha "  You will be prompted for username and password."
        chapisha ""
        chapisha chalk.bold("Example:")
        chapisha "  mango login"
        chapisha ""
        rudisha;
      }
      login_user(cmd)
      rudisha;
    }
  }
  
  fanya {
    data cmd = parse(cli, {
      help: ["--help", "-h", null, null],
      global: ["--global", "-g", null, null],
      forceBuild: ["--force-build", null, null, null]
    })
    kama cmd.command == "install" {
      kama cmd.flags.help {
        chapisha ""
        chapisha chalk.bold("mango install") + " - Install packages"
        chapisha ""
        chapisha chalk.bold("Usage:")
        chapisha "  mango install [packages...] [options]"
        chapisha ""
        chapisha chalk.bold("Options:")
        chapisha "  -g, --global    Install packages globally"
        chapisha "  -h, --help      Show this help"
        chapisha ""
        chapisha chalk.bold("Examples:")
        chapisha "  mango install                    # Install from swazi.json"
        chapisha "  mango install chalk              # Install specific package"
        chapisha "  mango install chalk@^1.0.0       # Install with version range"
        chapisha "  mango install -g swazi-cli       # Install globally"
        chapisha "  mango install pkg1 pkg2          # Install multiple"
        chapisha ""
        chapisha chalk.bold("Version Ranges:")
        chapisha "  1.2.3        Exact version"
        chapisha "  ^1.2.3       Compatible (>=1.2.3 <2.0.0)"
        chapisha "  ~1.2.3       Patch updates (>=1.2.3 <1.3.0)"
        chapisha "  >=1.0.0      Greater than or equal"
        chapisha "  latest       Latest version"
        chapisha "  *            Any version"
        chapisha ""
        rudisha;
      }
      install_package(cmd)
      rudisha;
    }
  }
  
  fanya {
    data cmd = parse(cli, {
      help: ["--help", "-h", null, null],
      global: ["--global", "-g", null, null],
      save: ["--save", "-s", null, null]
    })
    kama cmd.command == "unlink" {
      kama cmd.flags.help {
        chapisha ""
        chapisha chalk.bold("mango unlink") + " - Unlink packages"
        chapisha ""
        chapisha chalk.bold("Usage:")
        chapisha "  mango unlink <packages...> [options]"
        chapisha ""
        chapisha chalk.bold("Options:")
        chapisha "  -g, --global    Unlink global packages"
        chapisha "  -s, --save      Remove from manifest file"
        chapisha "  -h, --help      Show this help"
        chapisha ""
        chapisha chalk.bold("Examples:")
        chapisha "  mango unlink chalk"
        chapisha "  mango unlink chalk --save"
        chapisha "  mango unlink -g swazi-cli --save"
        chapisha ""
        rudisha;
      }
      unlink_package(cmd)
      rudisha;
    }
  }
  
  fanya {
    data cmd = parse(cli, {
      help: ["--help", "-h", null, null],
      global: ["--global", "-g", null, null]
    })
    kama cmd.command == "update" {
      kama cmd.flags.help {
        chapisha ""
        chapisha chalk.bold("mango update") + " - Update packages"
        chapisha ""
        chapisha chalk.bold("Usage:")
        chapisha "  mango update [packages...] [options]"
        chapisha ""
        chapisha chalk.bold("Options:")
        chapisha "  -g, --global    Update global packages"
        chapisha "  -h, --help      Show this help"
        chapisha ""
        chapisha chalk.bold("Examples:")
        chapisha "  mango update                     # Update all packages"
        chapisha "  mango update chalk               # Update specific package"
        chapisha "  mango update chalk@^2.0.0        # Update with new version"
        chapisha "  mango update -g swazi-cli        # Update global package"
        chapisha ""
        rudisha;
      }
      update_package(cmd)
      rudisha;
    }
  }
  
  fanya {
    data cmd = parse(cli, {
      help: ["--help", "-h", null, null],
      global: ["--global", "-g", null, null]
    })
    kama cmd.command == "list" {
      kama cmd.flags.help {
        chapisha ""
        chapisha chalk.bold("mango list") + " - List installed packages"
        chapisha ""
        chapisha chalk.bold("Usage:")
        chapisha "  mango list [options]"
        chapisha ""
        chapisha chalk.bold("Options:")
        chapisha "  -g, --global    List global packages"
        chapisha "  -h, --help      Show this help"
        chapisha ""
        chapisha chalk.bold("Examples:")
        chapisha "  mango list       # List local packages"
        chapisha "  mango list -g    # List global packages"
        chapisha ""
        rudisha;
      }
      list_packages(cmd)
      rudisha;
    }
  }
  
  fanya {
    data cmd = parse(cli, {
      help: ["--help", "-h", null, null]
    })
    kama cmd.command == "setup" {
      kama cmd.flags.help {
        chapisha ""
        chapisha chalk.bold("mango setup") + " - Initialize Mango"
        chapisha ""
        chapisha chalk.bold("Usage:")
        chapisha "  mango setup"
        chapisha ""
        chapisha chalk.bold("Description:")
        chapisha "  Creates global directories and provides instructions"
        chapisha "  for adding Mango to your system PATH."
        chapisha ""
        chapisha chalk.bold("What it does:")
        chapisha "  • Creates ~/.swazi/cache"
        chapisha "  • Creates ~/.swazi/vendor"
        chapisha "  • Creates ~/.swazi/globals"
        chapisha "  • Creates global manifest file"
        chapisha "  • Shows PATH setup instructions"
        chapisha ""
        chapisha chalk.bold("Example:")
        chapisha "  mango setup"
        chapisha ""
        rudisha;
      }
      mango_setup(cmd)
      rudisha;
    }
  }
  
  fanya {
    data cmd = parse(cli, {
      help: ["--help", "-h", null, null],
      limit: ["--limit", null, 20, "int"],
      offset: ["--offset", null, 0, "int"]
    })
    kama cmd.command == "search" {
      kama cmd.flags.help {
        chapisha ""
        chapisha chalk.bold("mango search") + " - Search for packages"
        chapisha ""
        chapisha chalk.bold("Usage:")
        chapisha "  mango search <query> [options]"
        chapisha ""
        chapisha chalk.bold("Options:")
        chapisha "  --limit <n>     Number of results (default: 20)"
        chapisha "  --offset <n>    Pagination offset (default: 0)"
        chapisha "  -h, --help      Show this help"
        chapisha ""
        chapisha chalk.bold("Examples:")
        chapisha "  mango search http"
        chapisha "  mango search \"web framework\""
        chapisha "  mango search http --limit 10"
        chapisha "  mango search api --offset 20"
        chapisha ""
        rudisha;
      }
      search_packages(cmd)
      rudisha;
    }
  }
  
  fanya {
    data cmd = parse(cli, {
      help: ["--help", "-h", null, null]
    })
    kama cmd.command == "info" {
      kama cmd.flags.help {
        chapisha ""
        chapisha chalk.bold("mango info") + " - Show package information"
        chapisha ""
        chapisha chalk.bold("Usage:")
        chapisha "  mango info <package>"
        chapisha ""
        chapisha chalk.bold("Description:")
        chapisha "  Displays detailed information about a package including:"
        chapisha "  • Description and author"
        chapisha "  • Available versions"
        chapisha "  • Dependencies"
        chapisha "  • Download statistics"
        chapisha "  • Repository and homepage links"
        chapisha ""
        chapisha chalk.bold("Examples:")
        chapisha "  mango info chalk"
        chapisha "  mango info @scope/package"
        chapisha ""
        rudisha;
      }
      info_package(cmd)
      rudisha;
    }
  }
  
  fanya {
    data cmd = parse(cli, {
      help: ["--help", "-h", null, null],
      sort: ["--sort", null, "recent", "string"],
      limit: ["--limit", null, 20, "int"]
    })
    kama cmd.command == "browse" {
      kama cmd.flags.help {
        chapisha ""
        chapisha chalk.bold("mango browse") + " - Browse packages"
        chapisha ""
        chapisha chalk.bold("Usage:")
        chapisha "  mango browse [options]"
        chapisha ""
        chapisha chalk.bold("Options:")
        chapisha "  --sort <type>   Sort by 'recent' or 'popular' (default: recent)"
        chapisha "  --limit <n>     Number of results (default: 20)"
        chapisha "  -h, --help      Show this help"
        chapisha ""
        chapisha chalk.bold("Examples:")
        chapisha "  mango browse"
        chapisha "  mango browse --sort popular"
        chapisha "  mango browse --sort recent --limit 30"
        chapisha ""
        rudisha;
      }
      browse_packages(cmd)
      rudisha;
    }
  }
  
  fanya {
    // reaching here is unknown command
    data cmd = parse(cli, {})
    tupa "Invalid command: " + (cmd.command == null ? "" : cmd.command) + "\n" +
    "    run mango --help for help";
  }
}
main() // start the main wheel
