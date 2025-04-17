#!/bin/bash
# Script to clean up after terraform destroy
# Run this on the server as root after terraform destroy completes

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting post-destroy cleanup...${NC}"

# Configuration
K8S_USER="k8s-admin"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root or with sudo privileges${NC}"
    exit 1
fi

# Clean up Kubernetes components
echo -e "${YELLOW}Cleaning up Kubernetes components...${NC}"
kubeadm reset -f || echo -e "${YELLOW}kubeadm reset failed or already cleaned up${NC}"
systemctl stop kubelet containerd || echo -e "${YELLOW}Services already stopped${NC}"

# Remove Kubernetes packages and directories
echo -e "${YELLOW}Removing Kubernetes packages...${NC}"
apt-get remove -y kubeadm kubectl kubelet kubernetes-cni || echo -e "${YELLOW}Kubernetes packages already removed${NC}"
apt-get remove -y containerd.io || echo -e "${YELLOW}Containerd already removed${NC}"

# Clean up directories
echo -e "${YELLOW}Removing Kubernetes and containerd directories...${NC}"
rm -rf /etc/kubernetes/
rm -rf /var/lib/kubelet/
rm -rf /var/lib/etcd/
rm -rf /etc/containerd/
rm -rf /var/lib/containerd/
rm -rf /etc/cni/
rm -rf /opt/cni/

# Reset network configurations
echo -e "${YELLOW}Resetting network configurations...${NC}"
rm -f /etc/sysctl.d/99-kubernetes-cri.conf
sysctl --system

# Clean up user kubectl configuration
if [ -d "/home/$K8S_USER/.kube" ]; then
    echo -e "${YELLOW}Removing user Kubernetes configuration...${NC}"
    rm -rf /home/$K8S_USER/.kube
fi

# Remove temporary sudo permissions
echo -e "${YELLOW}Removing temporary sudo permissions...${NC}"
rm -f /etc/sudoers.d/terraform_temp

echo -e "${GREEN}Cleanup complete! The system has been reset to pre-Kubernetes state.${NC}"
echo -e "${YELLOW}Note: To reinstall, you will need to run terraform_setup.sh again before terraform apply.${NC}"
