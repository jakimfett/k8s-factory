#!/bin/bash
# Script to prepare k8s-admin user for automated Terraform deployment
# Run this after setting up the k8s-admin user, before running Terraform

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Preparing for Terraform deployment with restricted sudo permissions...${NC}"

# Configuration
K8S_USER="k8s-admin"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root or with sudo privileges${NC}"
    exit 1
fi

# Add Docker repository (for containerd installation)
echo -e "${YELLOW}Setting up Docker repository for containerd installation...${NC}"

# Install prerequisites
apt update
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker repository (which provides containerd.io)
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Add Kubernetes repository (for Debian)
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
chmod a+r /etc/apt/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

# Update package lists
apt update

# Add temporary passwordless privileges for package installation during setup
echo -e "${YELLOW}Adding temporary permissions for initial setup...${NC}"
cat << EOF > /etc/sudoers.d/terraform_temp
# Temporary permissions for initial Terraform setup
# Allow specific sudo commands for Kubernetes setup
$K8S_USER ALL=(ALL) NOPASSWD: /usr/bin/apt update
$K8S_USER ALL=(ALL) NOPASSWD: /usr/bin/apt install -y *
$K8S_USER ALL=(ALL) NOPASSWD: /usr/bin/apt-mark hold *
$K8S_USER ALL=(ALL) NOPASSWD: /usr/bin/containerd config default
$K8S_USER ALL=(ALL) NOPASSWD: /usr/bin/tee *
$K8S_USER ALL=(ALL) NOPASSWD: /usr/bin/sed -i *
$K8S_USER ALL=(ALL) NOPASSWD: /usr/sbin/modprobe *
$K8S_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart containerd
$K8S_USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl enable containerd
$K8S_USER ALL=(ALL) NOPASSWD: /usr/bin/swapoff -a
$K8S_USER ALL=(ALL) NOPASSWD: /usr/bin/kubeadm init *
$K8S_USER ALL=(ALL) NOPASSWD: /bin/rm -f /etc/sudoers.d/terraform_temp
EOF
chmod 440 /etc/sudoers.d/terraform_temp

echo -e "${GREEN}Temporary permissions added successfully.${NC}"
echo -e "${YELLOW}Important notes:${NC}"
echo "1. These temporary permissions allow passwordless sudo for package management ONLY during initial setup."
echo "2. They will be used by Terraform to install and configure containerd and Kubernetes."
echo "3. The permissions are automatically removed at the end of the Terraform deployment."
echo "4. After deployment, only Kubernetes-specific operations will remain passwordless."
echo "5. Package management and general system operations will require password authentication."
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Run 'terraform init' and 'terraform apply' from your local machine"
echo "2. The temporary permissions will be removed automatically"
echo "3. After deployment, only limited passwordless sudo for Kubernetes operations will remain"
