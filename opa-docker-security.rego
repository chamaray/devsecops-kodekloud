package docker.security
import rego.v1

# Deny using latest tag
deny[msg] if {
    some i
    input[i].Cmd == "FROM"
    endswith(lower(input[i].Value[0]), ":latest")
    msg = "Do not use 'latest' tag"
}

# Deny running as root
deny[msg] if {
    not user_defined
    msg = "Container must not run as root user"
}

user_defined if {
    some i
    input[i].Cmd == "USER"
}

# Deny ADD commands
deny[msg] if {
    some i
    input[i].Cmd == "ADD"
    msg = "Use COPY instead of ADD"
}

# Deny dangerous RUN patterns
deny[msg] if {
    some i
    input[i].Cmd == "RUN"
    contains(lower(concat(" ", input[i].Value)), "apt-get upgrade")
    msg = "Avoid using apt-get upgrade"
}

deny[msg] if {
    some i
    input[i].Cmd == "RUN"
    contains(lower(concat(" ", input[i].Value)), "curl")
    contains(lower(concat(" ", input[i].Value)), "|")
    contains(lower(concat(" ", input[i].Value)), "sh")
    msg = "Avoid curl | sh pattern (possible security risk)"
}

deny[msg] if {
    some i
    input[i].Cmd == "RUN"
    contains(lower(concat(" ", input[i].Value)), "sudo")
    msg = "Avoid using sudo in Dockerfile"
}

# Deny exposing SSH
deny[msg] if {
    some i
    input[i].Cmd == "EXPOSE"
    input[i].Value[0] == "22"
    msg = "Do not expose SSH port (22)"
}
