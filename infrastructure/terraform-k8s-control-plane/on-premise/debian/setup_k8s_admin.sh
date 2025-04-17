#!/bin/bash
# Script to create a dedicated k8s-admin user with sudo privileges on Debian
# Run this script as root or with sudo privileges

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up Kubernetes admin user...${NC}"

# Configuration
K8S_USER="k8s-admin"
SSH_PUB_KEY="$(cat /tmp/id_ed25519.pub)" # Copy your public key to the server first

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root or with sudo privileges"
    exit 1
fi

# Create the user if it doesn't already exist
if ! id -u $K8S_USER >/dev/null 2>&1; then
    echo -e "${GREEN}Creating user $K8S_USER...${NC}"
    useradd -m -s /bin/bash $K8S_USER
    echo -e "${GREEN}User $K8S_USER created${NC}"
else
    echo -e "${YELLOW}User $K8S_USER already exists${NC}"
fi

# Set up restricted sudo access with hybrid approach
echo -e "${GREEN}Setting up restricted sudo privileges for $K8S_USER...${NC}"
cat << EOF > /etc/sudoers.d/$K8S_USER
# Kubernetes-specific commands that don't require password
$K8S_USER ALL=(ALL) NOPASSWD: /usr/bin/kubeadm, /usr/bin/kubelet, /usr/bin/kubectl

# Service management
$K8S_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl start kubelet, /usr/bin/systemctl stop kubelet, /usr/bin/systemctl restart kubelet, /usr/bin/systemctl status kubelet, /usr/bin/systemctl enable kubelet
$K8S_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl start containerd, /usr/bin/systemctl stop containerd, /usr/bin/systemctl restart containerd, /usr/bin/systemctl status containerd, /usr/bin/systemctl enable containerd

# Network configuration
$K8S_USER ALL=(ALL) NOPASSWD: /usr/bin/ip, /usr/sbin/sysctl -w net.bridge.bridge-nf-call-iptables=1, /usr/sbin/sysctl -w net.ipv4.ip_forward=1, /usr/sbin/sysctl -w net.bridge.bridge-nf-call-ip6tables=1, /usr/sbin/sysctl --system

# Required directory operations
$K8S_USER ALL=(ALL) NOPASSWD: /bin/mkdir -p /etc/containerd

# Require password for package management and general system operations
$K8S_USER ALL=(ALL) /usr/bin/apt, /usr/bin/apt-get, /usr/bin/apt-key, /usr/bin/apt-mark, /usr/bin/systemctl, /usr/bin/tee
EOF
chmod 440 /etc/sudoers.d/$K8S_USER

# Pre-create .kube directory for user
echo -e "${GREEN}Creating Kubernetes config directory for $K8S_USER...${NC}"
mkdir -p /home/$K8S_USER/.kube
chown $K8S_USER:$K8S_USER /home/$K8S_USER/.kube

# Create SSH directory and add authorized key
echo -e "${GREEN}Setting up SSH for $K8S_USER...${NC}"
mkdir -p /home/$K8S_USER/.ssh
echo "$SSH_PUB_KEY" > /home/$K8S_USER/.ssh/authorized_keys
chown -R $K8S_USER:$K8S_USER /home/$K8S_USER/.ssh
chmod 700 /home/$K8S_USER/.ssh
chmod 600 /home/$K8S_USER/.ssh/authorized_keys

# Optional: Set a secure random password (uncomment if needed)
# NEW_PASSWORD=$(openssl rand -base64 12)
# echo "$K8S_USER:$NEW_PASSWORD" | chpasswd
# echo -e "${GREEN}Set password for $K8S_USER: $NEW_PASSWORD${NC}"

echo -e "${GREEN}User $K8S_USER has been set up with sudo privileges and SSH access${NC}"
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Verify SSH access: ssh $K8S_USER@your-server-ip"
echo "2. Run 'terraform init' and 'terraform apply' from your local machine"
echo "3. The Kubernetes cluster will be set up automatically with containerd"
