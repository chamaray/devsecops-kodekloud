#!/bin/bash
set -e

echo "========= SYSTEM UPDATE ========="
apt-get update -y
apt-get upgrade -y
apt-get install -y curl apt-transport-https ca-certificates gnupg lsb-release software-properties-common

# --------------------------------------------------
# 🎨 NICE TERMINAL PROMPT
# --------------------------------------------------
echo "========= SETTING PROMPT ========="
echo "force_color_prompt=yes" >> ~/.bashrc
echo "PS1='\[\e[01;36m\]\u@\H:\w\\$ \[\033[0m\]'" >> ~/.bashrc
source ~/.bashrc

# --------------------------------------------------
# 🐳 INSTALL DOCKER (LATEST)
# --------------------------------------------------
echo "========= INSTALLING DOCKER ========="

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Docker daemon config
cat <<EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "storage-driver": "overlay2"
}
EOF

systemctl enable docker
systemctl restart docker

# --------------------------------------------------
# ☸️ INSTALL KUBERNETES (LATEST STABLE)
# --------------------------------------------------
echo "========= INSTALLING KUBERNETES ========="

KUBE_VERSION="1.29"

curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/ /" \
| tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet

# --------------------------------------------------
# ☸️ INIT K8s CLUSTER
# --------------------------------------------------
echo "========= INITIALIZING CLUSTER ========="

swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

kubeadm reset -f || true

kubeadm init --kubernetes-version=v${KUBE_VERSION} --pod-network-cidr=10.244.0.0/16

# Kube config
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# --------------------------------------------------
# 🌐 NETWORK (FLANNEL - stable choice)
# --------------------------------------------------
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

sleep 30

# Allow scheduling on control plane
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

kubectl get nodes -o wide

# --------------------------------------------------
# ☕ JAVA + MAVEN
# --------------------------------------------------
echo "========= INSTALLING JAVA & MAVEN ========="
apt-get install -y openjdk-17-jdk maven
java -version
mvn -v

# --------------------------------------------------
# 🔧 JENKINS (UPDATED METHOD)
# --------------------------------------------------
echo "========= INSTALLING JENKINS ========="

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
| tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/ \
| tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update -y
apt-get install -y jenkins

systemctl enable jenkins
systemctl start jenkins

# Jenkins permissions (SAFE version)
usermod -aG docker jenkins

# ⚠️ DO NOT DO THIS IN PROD
# echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# --------------------------------------------------
# ✅ COMPLETED
# --------------------------------------------------
echo "========= SETUP COMPLETE ========="

echo "Jenkins initial password:"
cat /var/lib/jenkins/secrets/initialAdminPassword
