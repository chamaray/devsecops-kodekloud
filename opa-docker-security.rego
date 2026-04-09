package main

########################################
# Deny rules (fail the build)
########################################

# 1. Do not use latest tag
deny[msg] if {
  input[i].Cmd == "from"
  endswith(lower(input[i].Value[0]), ":latest")
  msg := "Do not use 'latest' tag for base images"
}

# 2. Use minimal base images (alpine/slim)
deny[msg] if {
  input[i].Cmd == "from"
  not contains(lower(input[i].Value[0]), "alpine")
  not contains(lower(input[i].Value[0]), "slim")
  msg := "Use minimal base images like alpine or slim"
}

# 3. Avoid root user
deny[msg] if {
  not user_defined
  msg := "Container must not run as root user"
}

user_defined if {
  some i
  input[i].Cmd == "user"
}

# 4. Avoid ADD (use COPY instead)
deny[msg] if {
  input[i].Cmd == "add"
  msg := "Use COPY instead of ADD"
}

# 5. Avoid installing unnecessary packages
deny[msg] if {
  input[i].Cmd == "run"
  contains(cmd(input[i]), "apt-get upgrade")
  msg := "Avoid using apt-get upgrade"
}

# 6. Avoid curl | bash (security risk)
deny[msg] if {
  input[i].Cmd == "run"
  contains(cmd(input[i]), "curl")
  contains(cmd(input[i]), "|")
  contains(cmd(input[i]), "sh")
  msg := "Avoid curl | sh pattern (possible security risk)"
}

# 7. Avoid using sudo
deny[msg] if {
  input[i].Cmd == "run"
  contains(cmd(input[i]), "sudo")
  msg := "Avoid using sudo in Dockerfile"
}

# 8. Ensure no sensitive ports exposed
deny[msg] if {
  input[i].Cmd == "expose"
  input[i].Value[0] == "22"
  msg := "Do not expose SSH port (22)"
}

########################################
# Warning rules (do not fail build)
########################################

warn[msg] if {
  input[i].Cmd == "run"
  not contains(cmd(input[i]), "--no-cache")
  contains(cmd(input[i]), "apk add")
  msg := "Use --no-cache with apk add"
}

warn[msg] if {
  input[i].Cmd == "copy"
  not contains(cmd(input[i]), "--chown")
  msg := "Use --chown flag with COPY"
}

warn[msg] if {
  input[i].Cmd == "healthcheck"
  msg := "Healthcheck is defined"
}

warn[msg] if {
  not healthcheck_defined
  msg := "Consider adding HEALTHCHECK"
}

healthcheck_defined if {
  some i
  input[i].Cmd == "healthcheck"
}

########################################
# Helper function
########################################

cmd(x) := lower(concat(" ", x.Value))
