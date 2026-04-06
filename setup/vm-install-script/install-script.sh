#!/bin/bash
echo ".........----------------#################._.-.-INSTALL-.-._.#################----------------........."
PS1='\[\e[01;36m\]\u\[\e[01;37m\]@\[\e[01;33m\]\H\[\e[01;37m\]:\[\e[01;32m\]\w\[\e[01;37m\]\$\[\033[0;37m\] '
grep -qF 'e[01;36m' ~/.bashrc || echo "PS1='\[\e[01;36m\]\u\[\e[01;37m\]@\[\e[01;33m\]\H\[\e[01;37m\]:\[\e[01;32m\]\w\[\e[01;37m\]\$\[\033[0;37m\] '" >> ~/.bashrc
grep -qF 'force_color_prompt' ~/.bashrc || sed -i '1s/^/force_color_prompt=yes\n/' ~/.bashrc

export DEBIAN_FRONTEND=noninteractive
apt-get autoremove -y -qq
apt-get update -qq

systemctl daemon-reload

# -------------------------------------------------------
# Kubernetes repo — clean write (no duplicates)
# -------------------------------------------------------
KUBE_MINOR=1.29

mkdir -p /etc/apt/keyrings

# --batch --yes prevents the interactive "Overwrite? (y/N)" prompt
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBE_MINOR}/deb/Release.key" \
  | gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Overwrite — not append — so re-runs don't accumulate duplicate lines
cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_MINOR}/deb/ /
EOF

KUBE_VERSION=1.29.0-1.1

apt-get update -qq
apt-get install -y docker.io vim build-essential jq python3-pip \
  kubelet=${KUBE_VERSION} \
  kubectl=${KUBE_VERSION} \
  kubeadm=${KUBE_VERSION}

pip3 install --quiet jc

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
kubeadm init --kubernetes-version=${KUBE_VERSION%-*} --skip-token-print
mkdir -p ~/.kube
cp /etc/kubernetes/admin.conf ~/.kube/config
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

echo "Waiting for weave-net rollout..."
kubectl -n kube-system rollout status daemonset/weave-net --timeout=180s

echo "untaint controlplane node"
NODE=$(kubectl get nodes -o=jsonpath='{.items[].metadata.name}')
kubectl taint node "$NODE" node.kubernetes.io/not-ready:NoSchedule-          2>/dev/null || true
kubectl taint node "$NODE" node-role.kubernetes.io/master:NoSchedule-         2>/dev/null || true
kubectl taint node "$NODE" node-role.kubernetes.io/control-plane:NoSchedule-  2>/dev/null || true
kubectl get node -o wide

echo ".........----------------#################._.-.-Java and MAVEN-.-._.#################----------------........."
apt-get install -y openjdk-11-jdk
java -version
apt-get install -y maven
mvn -v

echo ".........----------------#################._.-.-JENKINS-.-._.#################----------------........."

# Clean any stale/broken jenkins key and source list from previous runs
rm -f /usr/share/keyrings/jenkins.gpg
rm -f /etc/apt/keyrings/jenkins.gpg
rm -f /etc/apt/sources.list.d/jenkins.list

# Fetch the 2023 key — --batch --yes ensures no interactive prompt
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  | gpg --batch --yes --dearmor -o /usr/share/keyrings/jenkins.gpg

# Verify the key was actually written
if [[ ! -s /usr/share/keyrings/jenkins.gpg ]]; then
  echo "ERROR: Jenkins GPG key file is empty or missing — aborting"
  exit 1
fi

# Write source list (signed-by must match the path above)
cat > /etc/apt/sources.list.d/jenkins.list <<EOF
deb [signed-by=/usr/share/keyrings/jenkins.gpg] https://pkg.jenkins.io/debian-stable binary/
EOF

apt-get update -qq
apt-get install -y jenkins

systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

usermod -a -G docker jenkins
echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

echo ".........----------------#################._.-.-COMPLETED-.-._.#################----------------........."

JENKINS_IP=$(hostname -I | awk '{print $1}')
INITIAL_PW=/var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "Jenkins UI : http://${JENKINS_IP}:8080"
[[ -f "$INITIAL_PW" ]] && echo "Initial PW : $(cat "$INITIAL_PW")"
