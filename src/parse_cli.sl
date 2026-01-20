tumia regex

/**
 * {
 *  command: <string>,
 *  flags: { <key>: <value>, ... },
 *  args: [<positional args>]
 * }
*/

kazi parse(cli, dfns) {
  data command_obj = {};

  // usually the first arg is the command / subcommand
  command_obj.command = cli[0];
  command_obj.flags = {}
  command_obj.args = []
  data stopFlags = sikweli;
  data flag_pattern = (/^(-[a-zA-Z]\d*|-[a-zA-Z]{2,}|--[a-zA-Z][\w-]*(=(?:\S+|"[^"]*"|'[^']*'))?)$/);

  // loop through the rest and build flags and positional args
  kwa (data i = 0; i < (args ni cli.slice(1)).size; i++) {
    data c = args[i];
    kama (c == "--") {
      stopFlags = kweli;
      endelea;
    }
    
    kama stopFlags {
      command_obj.args.push(c)
      endelea;
    }
    
    kama !stopFlags na flag_pattern.test(c) {
      kama c.startsWith("--") na c.includes("=") na (p ni c.split("=")).size == 2 {
        kwa (dfn,idx) ktk dfns {
          kama dfns[dfn][0..2].kuna(p[0]) {
            kama dfns[dfn][3] === "int" {
              kama !(/\d+/).test(p[1]) {
                tupa p[0] + "=<arg>, " + "arg should be a number!";
              }
              command_obj.flags[dfn] = Namba(p[1]);
            }
            kama dfns[dfn][3] === "string" {
              command_obj.flags[dfn] = p[1];
            }
            simama; // break no more searching
          }
          endelea;
        }
        endelea;
      }
      
      kama c.startsWith("--") na ((/^--[a-zA-Z]+(?:-[a-zA-Z]+)*$/).test(c)) {
        kwa (dfn,idx) ktk dfns {
          kama dfns[dfn][0..2].kuna(c) {
            kama dfns[dfn][2] == kweli {
              kama args[i+1] na !flag_pattern.test(args[i+1]) {
                kama dfns[dfn][3] === "int" {
                  kama !(/\d+/).test(args[i+1]) {
                    tupa args[i+1] + " <arg>, " + "arg should be a number!";
                  }
                  command_obj.flags[dfn] = Namba(args[i+1]);
                }
                kama dfns[dfn][3] === "string" {
                  command_obj.flags[dfn] = args[i+1];
                }
                i++
                simama;
              }
              tupa "Use " + c + "=" + "<required> or " + c + " <arg> to set required argument.\n" + c + "=<arg> is required"
            }
            kama dfns[dfn][2] != null na  dfns[dfn][2] != kweli {
              kama args[i+1] na !flag_pattern.test(args[i+1]) {
                kama dfns[dfn][3] === "int" {
                  kama !(/\d+/).test(args[i+1]) {
                    tupa args[i+1] + " <arg>, " + "arg should be a number!";
                  }
                  command_obj.flags[dfn] = Namba(args[i+1]);
                }
                kama dfns[dfn][3] === "string" {
                  command_obj.flags[dfn] = args[i+1];
                }
                i++
                simama;
              }
              command_obj.flags[dfn] = dfns[dfn][2];
              simama;
            }
            command_obj.flags[dfn] = kweli
            simama;
          }
        }
        endelea;
      }
      
      kama c.startsWith("-") na (/^-[a-zA-Z]$/).test(c) {
        kwa (dfn,idx) ktk dfns {
          kama dfns[dfn][0..2].kuna(c) {
            kama dfns[dfn][2] != null {
              kama dfns[dfn][2] == kweli {
                kama !args[i+1] || flag_pattern.test(args[i+1]) {
                  tupa c + " requires an argument or a default value, " + c + " <arg>";
                }
                command_obj.flags[dfn] = (dfns[dfn][3] == "int" na ((/\d+/).test(args[i+1]))) ? Namba(args[i+1]) : args[i+1]; // required flag argument upfront
                i++; // inrement
                simama;
              }
              sivyo {
                kama args[i+1] na !flag_pattern.test(args[i+1]) {
                  command_obj.flags[dfn] = (dfns[dfn][3] == "int" na ((/\d+/).test(args[i+1]))) ? Namba(args[i+1]) : args[i+1];
                  i++
                  simama;
                }
                command_obj.flags[dfn] = dfns[dfn][2]
              }
              simama;
            }
            command_obj.flags[dfn] = kweli
            simama;
          }
        }
        endelea;
      }
      
      
      kama c.startsWith("-") na ((/^-[a-zA-Z][a-zA-Z0-9]+$/).test(c)) {
        kwa(data j = 0; j < (chs ni c.split().slice(1)).size; j++) {
          kwa (dfn,idx) ktk dfns {
            kama dfns[dfn][0..2].kuna("-" + chs[j]) {
              kama dfns[dfn][2] == null {
                command_obj.flags[dfn] = kweli
                simama
              }
              sivyo kama dfns[dfn][2] != null {
                
                // everything after the flag character is the value
                data rest = c.substr(j + 2);
              
                kama rest == "" {
                  tupa "-" + chs[j] + " requires a value, eg: -" + chs[j] + "5000";
                }
              
                kama dfns[dfn][3] == "int" {
                  kama !(/^\d+$/).test(rest) {
                    tupa "-" + chs[j] + " requires an int value, eg: -" + chs[j] + "6000";
                  }
                  command_obj.flags[dfn] = Namba(rest);
                  simama;
                }
              
                kama dfns[dfn][3] == "string" {
                  command_obj.flags[dfn] = rest;
                  simama;
                }
              
                tupa "Invalid definition flags type! \nOnly allow 'int' | 'string'";
              }
              sivyo {
                tupa "Invalid flag pattern!"
              }
              simama;
            }
          }
        }
        endelea
      }
      
      endelea;
    }
    
    kama c.startsWith("-") {
      tupa "Invalid flags passed: " + c;
    }
    command_obj.args.push(c)
    
  }

  rudisha command_obj;
}

ruhusu {parse}