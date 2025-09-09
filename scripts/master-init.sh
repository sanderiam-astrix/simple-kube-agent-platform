#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Kubernetes repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${kubernetes_version}/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${kubernetes_version}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# Update package list
apt-get update

# Install Kubernetes components
apt-get install -y kubelet=${kubernetes_version}.0-1.1 kubeadm=${kubernetes_version}.0-1.1 kubectl=${kubernetes_version}.0-1.1

# Hold packages to prevent automatic updates
apt-mark hold kubelet kubeadm kubectl

# Install containerd
apt-get install -y containerd

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Enable systemd cgroup driver
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd
systemctl restart containerd
systemctl enable containerd

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get install -y unzip
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Initialize Kubernetes cluster
kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Configure kubectl for root user
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

# Install Flannel CNI
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Wait for nodes to be ready
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Create service account for AWS Load Balancer Controller
kubectl create serviceaccount aws-load-balancer-controller -n kube-system

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=ai-agent-lab-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=${aws_region}

# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Create namespace for AI agent
kubectl create namespace ai-agent

# Install AWS EBS CSI driver for persistent volumes
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.19"

# Create storage class for EBS
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

# Create AI agent deployment with proper configuration
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Update the deployment with correct account ID
sed "s/ACCOUNT_ID/$ACCOUNT_ID/g" /tmp/ai-agent-deployment.yaml > /tmp/ai-agent-deployment-updated.yaml
kubectl apply -f /tmp/ai-agent-deployment-updated.yaml

# Generate join command for workers
JOIN_COMMAND=$(kubeadm token create --print-join-command)
echo "#!/bin/bash" > /home/ubuntu/join-cluster.sh
echo "set -e" >> /home/ubuntu/join-cluster.sh
echo "sudo $JOIN_COMMAND" >> /home/ubuntu/join-cluster.sh
chmod +x /home/ubuntu/join-cluster.sh
chown ubuntu:ubuntu /home/ubuntu/join-cluster.sh

# Wait for deployment to be ready
kubectl wait --for=condition=available deployment/claude-code-agent -n ai-agent --timeout=300s

# Create kubeconfig for external access
cat <<EOF > /home/ubuntu/kubeconfig
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: $(cat /etc/kubernetes/pki/ca.crt | base64 -w 0)
    server: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
users:
- name: kubernetes-admin
  user:
    client-certificate-data: $(cat /etc/kubernetes/pki/apiserver.crt | base64 -w 0)
    client-key-data: $(cat /etc/kubernetes/pki/apiserver.key | base64 -w 0)
EOF

chown ubuntu:ubuntu /home/ubuntu/kubeconfig
chmod 600 /home/ubuntu/kubeconfig

# Create setup completion marker
touch /var/log/k8s-setup-complete

echo "Kubernetes cluster setup completed successfully!"
echo "Master node IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Kubeconfig location: /home/ubuntu/kubeconfig"
