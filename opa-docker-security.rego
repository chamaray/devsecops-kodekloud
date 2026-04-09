package main

# Deny rules (fail the build)
deny[msg] {
    some i
    input[i].Cmd == "FROM"
    endswith(lower(input[i].Value[0]), ":latest")
    msg := "Do not use 'latest' tag for base images"
}

deny[msg] {
    some i
    input[i].Cmd == "FROM"
    not contains(lower(input[i].Value[0]), "alpine")
    not contains(lower(input[i].Value[0]), "slim")
    msg := "Use minimal base images like alpine or slim"
}

deny[msg] {
    not user_defined
    msg := "Container must not run as root user"
}

user_defined {
    some i
    input[i].Cmd == "USER"
}

deny[msg] {
    some i
    input[i].Cmd == "ADD"
    msg := "Use COPY instead of ADD"
}

deny[msg] {
    some i
    input[i].Cmd == "RUN"
    contains(cmd(input[i]), "apt-get upgrade")
    msg := "Avoid using apt-get upgrade"
}

deny[msg] {
    some i
    input[i].Cmd == "RUN"
    contains(cmd(input[i]), "curl")
    contains(cmd(input[i]), "|")
    contains(cmd(input[i]), "sh")
    msg := "Avoid curl | sh pattern (possible security risk)"
}

deny[msg] {
    some i
    input[i].Cmd == "RUN"
    contains(cmd(input[i]), "sudo")
    msg := "Avoid using sudo in Dockerfile"
}

deny[msg] {
    some i
    input[i].Cmd == "EXPOSE"
    input[i].Value[0] == "22"
    msg := "Do not expose SSH port (22)"
}

# Warning rules (do not fail build)
warn[msg] {
    some i
    input[i].Cmd == "RUN"
    contains(cmd(input[i]), "apk add")
    not contains(cmd(input[i]), "--no-cache")
    msg := "Use --no-cache with apk add"
}

warn[msg] {
    some i
    input[i].Cmd == "COPY"
    not contains(cmd(input[i]), "--chown")
    msg := "Use --chown flag with COPY"
}

warn[msg] {
    not healthcheck_defined
    msg := "Consider adding HEALTHCHECK"
}

healthcheck_defined {
    some i
    input[i].Cmd == "HEALTHCHECK"
}

# Helper function to join values
cmd(x) = c {
    c := lower(concat(" ", x.Value))
}
