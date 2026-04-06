#!/bin/bash
echo ".........----------------#################._.-.-INSTALL-.-._.#################----------------........."
PS1='\[\e[01;36m\]\u\[\e[01;37m\]@\[\e[01;33m\]\H\[\e[01;37m\]:\[\e[01;32m\]\w\[\e[01;37m\]\$\[\033[0;37m\] '
echo "PS1='\[\e[01;36m\]\u\[\e[01;37m\]@\[\e[01;33m\]\H\[\e[01;37m\]:\[\e[01;32m\]\w\[\e[01;37m\]\$\[\033[0;37m\] '" >> ~/.bashrc
sed -i '1s/^/force_color_prompt=yes\n/' ~/.bashrc
source ~/.bashrc
apt-get autoremove -y
apt-get update

systemctl daemon-reload

# -------------------------------------------------------
# FIX 1: Remove stale kubernetes.list before writing it
#         (prevents "configured multiple times" warnings)
# -------------------------------------------------------
rm -f /etc/apt/sources.list.d/kubernetes.list

# Use new pkgs.k8s.io repo with proper signed-by key
KUBE_VERSION=1.29
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

KUBE_PKG_VERSION=1.29.0-1.1
apt-get update
apt-get install -y docker.io vim build-essential jq python3-pip \
  kubelet=${KUBE_PKG_VERSION} \
  kubectl=${KUBE_PKG_VERSION} \
  kubeadm=${KUBE_PKG_VERSION}
pip3 install jc

### UUID of VM
### comment below line if this Script is not executed on Cloud based VMs
jc dmidecode | jq .[1].values.uuid -r

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "storage-driver": "overlay2"
}
EOF
mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload
systemctl restart docker
systemctl enable docker
systemctl enable kubelet
systemctl start kubelet

echo ".........----------------#################._.-.-KUBERNETES-.-._.#################----------------........."
rm -f /root/.kube/config
kubeadm reset -f
kubeadm init --kubernetes-version=${KUBE_PKG_VERSION%-*} --skip-token-print
mkdir -p ~/.kube
sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

echo "Waiting for weave-net rollout..."
kubectl -n kube-system rollout status daemonset/weave-net --timeout=180s

echo "untaint controlplane node"
kubectl taint node $(kubectl get nodes -o=jsonpath='{.items[].metadata.name}') node.kubernetes.io/not-ready:NoSchedule- 2>/dev/null || true
kubectl taint node $(kubectl get nodes -o=jsonpath='{.items[].metadata.name}') node-role.kubernetes.io/master:NoSchedule- 2>/dev/null || true
kubectl taint node $(kubectl get nodes -o=jsonpath='{.items[].metadata.name}') node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || true
kubectl get node -o wide

echo ".........----------------#################._.-.-Java and MAVEN-.-._.#################----------------........."
sudo apt install openjdk-11-jdk -y
java -version
sudo apt install -y maven
mvn -v

echo ".........----------------#################._.-.-JENKINS-.-._.#################----------------........."

# -------------------------------------------------------
# FIX 2: Jenkins GPG key — use new 2023 key with signed-by
#         (the old wget | apt-key add method no longer works)
# -------------------------------------------------------
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  | gpg --dearmor -o /etc/apt/keyrings/jenkins.gpg
chmod a+r /etc/apt/keyrings/jenkins.gpg

# Overwrite (not append) the jenkins source list
echo "deb [signed-by=/etc/apt/keyrings/jenkins.gpg] \
https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list

sudo apt-get update
sudo apt-get install -y jenkins
systemctl daemon-reload
systemctl enable jenkins
sudo systemctl start jenkins
sudo usermod -a -G docker jenkins
echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

echo ".........----------------#################._.-.-COMPLETED-.-._.#################----------------........."

JENKINS_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "Jenkins UI : http://${JENKINS_IP}:8080"
INITIAL_PW=/var/lib/jenkins/secrets/initialAdminPassword
if [[ -f "$INITIAL_PW" ]]; then
  echo "Initial PW : $(cat "$INITIAL_PW")"
fi
