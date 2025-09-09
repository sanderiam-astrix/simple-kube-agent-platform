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

# Debug: Check what files are in /tmp
echo "Debug: Checking /tmp directory contents..."
ls -la /tmp/ | head -10

# Install Claude Code
echo "Installing Claude Code on worker node..."
if [ -f "/tmp/install-claude-code.sh" ]; then
    echo "Claude Code installation script found, executing..."
    chmod +x /tmp/install-claude-code.sh
    if /tmp/install-claude-code.sh; then
        echo "Claude Code installed successfully on worker node"
        echo "Checking service status..."
        systemctl status claude-code --no-pager -l || echo "Service status check failed"
        echo "Testing service endpoints..."
        curl -f http://localhost:8080/health || echo "Health endpoint not ready"
        curl -f http://localhost:8080/status || echo "Status endpoint not ready"
    else
        echo "Claude Code installation failed, continuing with cluster setup..."
        echo "Checking for any error logs..."
        journalctl -u claude-code --no-pager -l || echo "No service logs found"
    fi
else
    echo "Claude Code installation script not found at /tmp/install-claude-code.sh"
    echo "Available files in /tmp:"
    ls -la /tmp/ | grep -E "(install|claude)" || echo "No Claude-related files found"
fi

# Wait for master node to be ready
echo "Waiting for master node to be ready..."
sleep 120

# Try to get join command from master node
echo "Attempting to join cluster..."
for i in {1..10}; do
    if scp -o StrictHostKeyChecking=no ubuntu@${master_ip}:/home/ubuntu/join-cluster.sh /tmp/join-cluster.sh 2>/dev/null; then
        echo "Join command retrieved from master node"
        chmod +x /tmp/join-cluster.sh
        /tmp/join-cluster.sh
        break
    else
        echo "Attempt $i: Master node not ready yet, waiting..."
        sleep 30
    fi
done

# If join failed, create a script for manual joining
if [ ! -f /tmp/join-cluster.sh ]; then
    echo "Could not automatically join cluster. Creating manual join script..."
    cat <<'EOF' > /home/ubuntu/join-cluster.sh
#!/bin/bash
echo "Manual join required. Please get the join command from the master node:"
echo "scp ubuntu@<master-ip>:/home/ubuntu/join-cluster.sh ./join-cluster.sh"
echo "sudo ./join-cluster.sh"
EOF
    chmod +x /home/ubuntu/join-cluster.sh
    chown ubuntu:ubuntu /home/ubuntu/join-cluster.sh
fi

# Create setup completion marker
touch /var/log/k8s-worker-setup-complete

echo "Worker node setup completed successfully!"
echo "Worker node IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
