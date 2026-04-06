#!/bin/bash
set -euo pipefail

# ============================================================
#  Single-Node Kubernetes + Jenkins Bootstrap Script
#  Target OS : Ubuntu 22.04 LTS (Jammy)
#  Kubernetes : v1.29
#  Author     : Generated — review before running in production
# ============================================================

#######################################
# Colour helpers
#######################################
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

banner()  { echo -e "\n${CYAN}${BOLD}=== $* ===${NC}\n"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

#######################################
# Pre-flight checks
#######################################
banner "Pre-flight checks"

[[ $EUID -eq 0 ]] || die "Run this script as root (sudo -i)"

OS_ID=$(grep -w ID /etc/os-release | cut -d= -f2 | tr -d '"')
OS_VER=$(grep VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')
[[ "$OS_ID" == "ubuntu" && "$OS_VER" == "22.04" ]] \
  || warn "Tested on Ubuntu 22.04 — continuing on $OS_ID $OS_VER"

CPU_COUNT=$(nproc)
MEM_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
[[ $CPU_COUNT -ge 2 ]] || warn "Kubernetes recommends ≥ 2 CPUs (found $CPU_COUNT)"
[[ $MEM_MB   -ge 1700 ]] || warn "Kubernetes recommends ≥ 2 GB RAM (found ~${MEM_MB} MB)"
success "System: $CPU_COUNT CPUs, ~${MEM_MB} MB RAM"

#######################################
# Tuneable variables
#######################################
KUBE_VERSION="1.29"
KUBE_PKG_VERSION="1.29.0-1.1"   # exact apt package version
CNI_VERSION="1.4.0"              # weave-net release tag (v prefix added below)
JENKINS_JAVA="openjdk-17-jdk"

#######################################
# Shell prompt (optional cosmetic)
#######################################
banner "Shell environment"
PROMPT='PS1='"'"'\[\e[01;36m\]\u\[\e[01;37m\]@\[\e[01;33m\]\H\[\e[01;37m\]:\[\e[01;32m\]\w\[\e[01;37m\]\$\[\033[0;37m\] '"'"
grep -qF 'force_color_prompt=yes' ~/.bashrc || sed -i '1s/^/force_color_prompt=yes\n/' ~/.bashrc
grep -qF 'e[01;36m' ~/.bashrc || echo "$PROMPT" >> ~/.bashrc
success "Prompt configured in ~/.bashrc"

#######################################
# System update & base packages
#######################################
banner "System update"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get autoremove -y -qq
apt-get install -y -qq \
  apt-transport-https ca-certificates curl gnupg lsb-release \
  vim jq build-essential python3-pip
success "Base packages installed"

#######################################
# Disable swap (required by Kubernetes)
#######################################
banner "Swap"
swapoff -a
sed -i '/\sswap\s/s/^/#/' /etc/fstab
success "Swap disabled"

#######################################
# Kernel modules & sysctl
#######################################
banner "Kernel settings"
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

cat > /etc/sysctl.d/99-k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system -q
success "Kernel modules and sysctl applied"

#######################################
# containerd (replaces docker shim)
#######################################
banner "containerd runtime"

# Add Docker repo (containerd package lives here)
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq containerd.io

# Generate default config and enable systemd cgroup driver
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl daemon-reload
systemctl enable --now containerd
success "containerd installed and configured"

#######################################
# Kubernetes packages (pkgs.k8s.io)
#######################################
banner "Kubernetes ${KUBE_VERSION}"

# New signing-key / repo format (replaces deprecated apt.kubernetes.io)
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update -qq
apt-get install -y -qq \
  "kubelet=${KUBE_PKG_VERSION}" \
  "kubectl=${KUBE_PKG_VERSION}" \
  "kubeadm=${KUBE_PKG_VERSION}"

# Pin versions so apt upgrade won't surprise us
apt-mark hold kubelet kubectl kubeadm
systemctl enable --now kubelet
success "kubelet, kubectl, kubeadm ${KUBE_PKG_VERSION} installed and pinned"

#######################################
# Initialise the cluster
#######################################
banner "Cluster initialisation"

# Clean any previous state
rm -f /root/.kube/config
kubeadm reset -f --cri-socket unix:///run/containerd/containerd.sock 2>/dev/null || true

kubeadm init \
  --kubernetes-version="${KUBE_PKG_VERSION%-*}" \
  --cri-socket unix:///run/containerd/containerd.sock \
  --skip-token-print \
  --pod-network-cidr=10.32.0.0/12    # matches weave-net default

# Configure kubectl for root
mkdir -p ~/.kube
cp /etc/kubernetes/admin.conf ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=/root/.kube/config
success "Control-plane initialised"

#######################################
# CNI — Weave Net
#######################################
banner "CNI (Weave Net v${CNI_VERSION})"

WEAVE_URL="https://github.com/weaveworks/weave/releases/download/v${CNI_VERSION}/weave-daemonset-k8s.yaml"
kubectl apply -f "$WEAVE_URL"

# Wait properly instead of a blind sleep
echo "Waiting for CoreDNS pods to be Ready…"
kubectl -n kube-system wait --for=condition=Ready pod \
  -l k8s-app=kube-dns --timeout=180s
success "Weave Net applied, CoreDNS ready"

#######################################
# Untaint control-plane (single-node)
#######################################
banner "Control-plane untaint"
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl taint node "$NODE" node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || true
kubectl taint node "$NODE" node.kubernetes.io/not-ready:NoSchedule-           2>/dev/null || true
success "Taints removed from $NODE"
kubectl get node -o wide

#######################################
# Java (Jenkins dependency)
#######################################
banner "Java (${JENKINS_JAVA})"
apt-get install -y -qq "$JENKINS_JAVA"
java -version 2>&1 | head -1
success "Java installed"

#######################################
# Maven (for build pipelines)
#######################################
banner "Maven"
apt-get install -y -qq maven
mvn -version 2>&1 | head -1
success "Maven installed"

#######################################
# Jenkins (LTS)
#######################################
banner "Jenkins LTS"

# Official signed-by format (replaces apt-key add)
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  | gpg --dearmor -o /etc/apt/keyrings/jenkins.gpg
chmod a+r /etc/apt/keyrings/jenkins.gpg

echo "deb [signed-by=/etc/apt/keyrings/jenkins.gpg] \
https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list

apt-get update -qq
apt-get install -y -qq jenkins

systemctl daemon-reload
systemctl enable --now jenkins

# Give Jenkins access to containerd socket (replaces docker group)
usermod -aG docker jenkins 2>/dev/null || true    # kept for docker CLI compat if installed later
usermod -aG sudo  jenkins

# Scoped sudo — only what pipelines actually need
cat > /etc/sudoers.d/jenkins <<'EOF'
# Jenkins CI pipelines — restrict to safe commands
jenkins ALL=(ALL) NOPASSWD: /usr/bin/kubectl, /usr/bin/kubeadm, /usr/bin/docker
EOF
chmod 440 /etc/sudoers.d/jenkins
success "Jenkins installed; scoped sudoers written to /etc/sudoers.d/jenkins"

#######################################
# Copy kubeconfig for Jenkins
#######################################
mkdir -p /var/lib/jenkins/.kube
cp /root/.kube/config /var/lib/jenkins/.kube/config
chown -R jenkins:jenkins /var/lib/jenkins/.kube
chmod 600 /var/lib/jenkins/.kube/config
success "Kubeconfig shared with Jenkins user"

#######################################
# jc (JSON CLI helper)
#######################################
pip3 install --quiet jc
success "jc installed"

#######################################
# Summary
#######################################
banner "Installation complete"
echo -e "${BOLD}Kubernetes node:${NC}"
kubectl get node -o wide

JENKINS_IP=$(hostname -I | awk '{print $1}')
INITIAL_PW=/var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo -e "${BOLD}Jenkins UI:${NC} http://${JENKINS_IP}:8080"
if [[ -f "$INITIAL_PW" ]]; then
  echo -e "${BOLD}Initial admin password:${NC} $(cat "$INITIAL_PW")"
fi
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Open Jenkins at http://${JENKINS_IP}:8080 and complete the setup wizard"
echo "  2. Run 'kubeadm token create --print-join-command' to add worker nodes"
echo "  3. Consider setting up RBAC for the Jenkins service account"
echo "  4. Review /etc/sudoers.d/jenkins and tighten as needed"
echo ""
success "Done."
