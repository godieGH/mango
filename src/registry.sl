tumia http
tumia json
tumia fs
tumia path
tumia process
tumia httpBody kutoka "vendor:http-body"

tumia "utils/helpers.swz"
tumia "./utils/logger.swz"

kazi check_server_health() {
  rudisha (unda Promise((resolve, reject) => {
    data client = http.client.get("http://localhost:8080/health")
    client.on("error", err => {
      LOG(ERROR, err)
      swazi.exit(0)
    })
    client.on("data", chunk => {
      data res = json.parse(chunk.str())
      resolve(res.success)
    })
  }))
}

kazi login(username, password) {
  data body = httpBody.json({
    username,
    password
  })
  data req = http.client.post("http://localhost:8080/api/auth/login", body.buffer(), {
    headers: body.headers()
  })
  rudisha (unda Promise((resolve, reject) => {
    req.on("error", (err) => {
      LOG(ERROR, err)
    })
    req.on("data", (chunk) => {
      
      data res = json.parse(chunk.str())
      kama !res.success {
        LOG(ERROR, "Failed on logging")
        LOG(ERROR, res.error); 
        chapisha (" --> Run `mango login` or `mango register` commands to login/register an account");
        swazi.exit(0);
      }
      resolve(res)
    })
  }))
}
kazi adduser(username, password, email) {
  
  data body = httpBody.json({
    username,
    password,
    email
  })
  data req = http.client.post("http://localhost:8080/api/auth/register", body.buffer(), {
    headers: body.headers()
  })
  rudisha (unda Promise((resolve, reject) => {
    req.on("error", (err) => {
      LOG(ERROR, err)
    })
    req.on("data", (chunk) => {
      
      data res = json.parse(chunk.str())
      kama !res.success {
        LOG(ERROR, "Failed to registr a user")
        LOG(ERROR, res.error); 
        chapisha (" --> Run `mango login` or `mango register` commands to login/register an account");
        swazi.exit(0);
      }
      resolve(res)
    })
  }))
}

kazi register_user(cli) {
  data username = soma("type in username: ")
  data email = soma("type in email: ")
  data password = soma("type in password: ")
  
  kama !username au !email au !password =>> LOG(ERROR, "Invalid credentials")
  adduser(username, password, email)
  .then(res => {
    LOG(INFO, res.message)
    chapisha "username: " + res.username;
    
    data home = process.getEnv("HOME")
    data cachepath = path.resolve(home, ".swazi")
    kama !fs.exists(cachepath) =>> fs.makeDir(cachepath)
    data content = res.token
    fs.writeFile(path.resolve(cachepath, "mangorc"), content)
  })
}
kazi login_user(cli) {
  data username = soma("type in username: ")
  data password = soma("type in password: ")
  
  kama !username au !password =>> LOG(ERROR, "Invalid loggin credentials")
  login(username, password)
  .then(res => {
    LOG(INFO, "successful login")
    chapisha "username: " + res.username;
    chapisha "email: " + res.email;
    
    data home = process.getEnv("HOME")
    data cachepath = path.resolve(home, ".swazi")
    kama !fs.exists(cachepath) =>> fs.makeDir(cachepath)
    data content = res.token
    fs.writeFile(path.resolve(cachepath, "mangorc"), content)
  })
}
kazi get_user_access_token() {
  data home = process.getEnv("HOME")
  data cachepath = path.resolve(home, ".swazi")
  kama !fs.exists(cachepath) {
    LOG(ERROR, "Please logging first before uploading to registry"); 
    chapisha (" --> Run `mango login` or `mango register` commands to login/register an account");
    swazi.exit(0);
  }
  jaribu {
    rudisha fs.readFile(path.resolve(cachepath, "mangorc"))
  } makosa _ {
    LOG(ERROR, "Error fetching token, please login")
    swazi.exit(0)
  }
}

// uploading_to_registry
kazi async uploading_to_registry(artifact, manifest, hash) {
  // check if server is availabale and healthy
  kama !(await check_server_health()) {
    LOG(ERROR, "Server currently is not availabale!")
  }
  
  // 1) get the access token 
  data accesstoken = get_user_access_token();
  
  // 2) make a upload request
  data body = httpBody.multipart((form) => {
    form.field("manifest", json.stringify(manifest))
    form.field("hash", hash)
    // the artifact
    form.file("artifact", artifact, manifest.tarball, "application/gzip")
  })
  data req = http.client.open("http://localhost:8080/api/packages/upload", {
    method: "POST",
    headers: {
      ...body.headers(),
      Authorization: "Bearer " + accesstoken
    },
    body: body.buffer()
  })
  req.on("error", (err) => {
    LOG(ERROR, err)
    swazi.exit(0)
  })
  req.on("data", (chunk) => {
    data res = json.parse(chunk.str())
    kama !res.success =>> rudisha LOG(ERROR, res.error)
    LOG(null, "✔ DONE! " + manifest.name + "@" + manifest.version)
  })
}

// export
ruhusu { uploading_to_registry, register_user, login_user }