#!/usr/bin/env swazi
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

kazi main() {
  // getting the cli arguments and call parse to parse them
  data cli = argv.slice(2)
  // publish command
  fanya {
    data cmd = parse(cli, {
      dryrun: ["--dry-run", null, null, null]
    })
    kama cmd.command == "publish" {
      publisher(cmd)
      rudisha;
    }
  }
  fanya {
    data cmd = parse(cli, {
      dryrun: ["--dry-run", null, null, null]
    })
    kama cmd.command == "pack" {
      packaging(cmd)
      rudisha;
    }
  }
  
  fanya {
    data cmd = parse(cli, {})
    kama cmd.command == "register" {
      register_user(cmd)
      rudisha;
    }
  }
  fanya {
    data cmd = parse(cli, {})
    kama cmd.command == "login" {
      login_user(cmd)
      rudisha;
    }
  }
  
  fanya {
    data cmd = parse(cli, {
      global: ["--global", "-g", null, null]
    })
    kama cmd.command == "install" {
      install_package(cmd)
      rudisha;
    }
  }
  fanya {
    data cmd = parse(cli, {
      global: ["--global", "-g", null, null],
      save: ["--save", "s", null, null]
    })
    kama cmd.command == "unlink" {
      unlink_package(cmd)
      rudisha;
    }
  }
  fanya {
    data cmd = parse(cli, {
      global: ["--global", "-g", null, null]
    })
    kama cmd.command == "update" {
      update_package(cmd)
      rudisha;
    }
  }
  fanya {
    data cmd = parse(cli, {
      global: ["--global", "-g", null, null]
    })
    kama cmd.command == "list" {
      list_packages(cmd)
      rudisha;
    }
  }
  fanya {
    data cmd = parse(cli, {})
    kama cmd.command == "setup" {
      mango_setup(cmd)
      rudisha;
    }
  }
  
  fanya {
    data cmd = parse(cli, {
      limit: ["--limit", null, kweli, "int"],
      offset: ["--offset", null, 0, "int"]
    })
    kama cmd.command == "search" {
      search_packages(cmd)
      rudisha;
    }
  }
  fanya {
    data cmd = parse(cli, {})
    kama cmd.command == "info" {
      info_package(cmd)
      rudisha;
    }
  }
  fanya {
    data cmd = parse(cli, {
      sort: ["--sort", null, "recent", "string"],
      limit: ["--limit", null, kweli, "int"]
    })
    kama cmd.command == "browse" {
      browse_packages(cmd)
      rudisha;
    }
  }
  
  fanya {
    // reaching here is unknown command
    data cmd = parse(cli, {})
    tupa "Invalid command: " + (cmd.command == null ? "" : cmd.command);
  }
}
main() // start the main wheel
