# Debian Kubernetes Control Plane

This Terraform module sets up a full Kubernetes control plane on an existing Debian server for the k8s-factory staging environment.

## Overview

This module:
- Installs containerd as the container runtime
- Configures containerd to use the systemd cgroup driver
- Sets up necessary kernel modules and sysctl parameters
- Installs Kubernetes components (kubeadm, kubelet, kubectl)
- Initializes a Kubernetes control plane with containerd configuration
- Configures Calico as the CNI network plugin
- Creates the k8s-factory namespace
- Retrieves the kubeconfig file for local access

## Prerequisites

- A Debian server with SSH access
- SSH private key for authentication
- Sudo privileges on the remote server
- At least 2 CPU cores and 2GB RAM
- At least 20GB of free disk space
- Network connectivity for the server

## Detailed Setup Instructions

### Step 1: Server Preparation

1. Start with a fresh Debian 12 (bookworm) installation

2. Ensure you have root or sudo access on the server

3. Copy your SSH public key to the server for initial access:
   ```bash
   # From your local machine
   scp ~/.ssh/id_ed25519.pub root@your-server-ip:/tmp/
   ```

### Step 2: Setting Up k8s-admin User and Sudo Permissions

1. Copy the setup script to the server:
   ```bash
   scp setup_k8s_admin.sh terraform_setup.sh k8s_admin_sudoers.conf terraform_temp_sudoers.conf root@your-server-ip:/tmp/
   ```

2. SSH into your server and run the user setup script:
   ```bash
   ssh root@your-server-ip
   chmod +x /tmp/setup_k8s_admin.sh
   /tmp/setup_k8s_admin.sh
   ```

3. Configure the permanent sudo permissions:
   ```bash
   # On the server as root
   sudo visudo -f /etc/sudoers.d/k8s-admin
   ```
   
   Copy and paste the contents of k8s_admin_sudoers.conf, then save and exit

4. Configure the temporary sudo permissions for Terraform:
   ```bash
   # On the server as root
   sudo visudo -f /etc/sudoers.d/terraform_temp
   ```
   
   Copy and paste the contents of terraform_temp_sudoers.conf, then save and exit

5. Run the Terraform setup script to prepare the repositories:
   ```bash
   chmod +x /tmp/terraform_setup.sh
   /tmp/terraform_setup.sh
   ```

6. Verify the k8s-admin user can SSH to the server:
   ```bash
   # From your local machine
   ssh k8s-admin@your-server-ip
   ```

### Step 3: Terraform Deployment

1. Copy the example variables file and customize it:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific server details
   ```

2. Initialize the Terraform module:
   ```bash
   terraform init
   ```

3. Preview the changes:
   ```bash
   terraform plan
   ```

4. Apply the configuration:
   ```bash
   terraform apply
   ```

### Step 4: Debugging Common Issues

#### sudo Permission Issues:

1. **Problem**: Terraform execution stops with sudo password prompt
   
   **Solution**: 
   - SSH into the server and check the sudo logs:
     ```bash
     sudo grep sudo /var/log/auth.log | tail
     ```
   - Identify the command that's failing
   - Update the terraform_temp_sudoers.conf file with the missing permission
   - Run `sudo visudo -f /etc/sudoers.d/terraform_temp` to update

2. **Problem**: sudo syntax errors when setting up permissions
   
   **Solution**:
   - Use `visudo -c` to check syntax before saving
   - For complex commands with quotes, use `k8s-admin ALL=(ALL) NOPASSWD: /path/to/command *` pattern

#### Repository Issues:

1. **Problem**: Package repositories not found
   
   **Solution**:
   - Verify Debian version: `cat /etc/os-release`
   - Use the correct repository URLs for your Debian version
   - For Debian 12 (bookworm), use paths shown in terraform_setup.sh

#### Containerd Configuration:

1. **Problem**: containerd fails to restart
   
   **Solution**:
   - Check containerd logs: `sudo journalctl -u containerd`
   - Verify systemd cgroup driver is configured: `grep SystemdCgroup /etc/containerd/config.toml`
   - Manually restart if needed: `sudo systemctl restart containerd`

5. Connect to your Kubernetes cluster:
   ```bash
   # The command will be shown in the Terraform output
   export KUBECONFIG=~/.kube/config-debian
   kubectl get nodes
   ```

## Prometheus Integration

This setup is designed to work with the k8s-factory Prometheus metrics system. The Rust aggregator service has native Prometheus integration, exposing metrics at the `/metrics` endpoint. Key metrics being tracked:

- Request counters by endpoint (`aggregator_requests_total{endpoint="..."}`)
- Response time histograms for echo servers (`aggregator_response_time_ms`)
- Buckets from 5ms to 1000ms for detailed performance analysis

The Kubernetes deployment will preserve these metrics capabilities when migrating from Docker to Kubernetes.

## Container Build Optimization

For the Rust aggregator service, the build process can be resource-intensive. The Terraform setup ensures that:

1. The Kubernetes node has sufficient resources for container builds
2. Docker caching is properly configured on the node
3. The Kubernetes configuration allows for efficient container lifecycle management

## Next Steps After Deployment

Once the Kubernetes control plane is running:

1. Deploy the k8s-factory Kubernetes manifests:
   ```bash
   kubectl apply -f /path/to/k8s-factory/kubernetes/base/namespaces.yaml
   kubectl apply -f /path/to/k8s-factory/kubernetes/base/aggregator/
   kubectl apply -f /path/to/k8s-factory/kubernetes/base/echo-services/
   ```

2. Verify the deployments:
   ```bash
   kubectl get all -n k8s-factory
   ```

3. Access the services and metrics:
   ```bash
   # For service access (determine the NodePort first)
   kubectl get svc -n k8s-factory
   
   # For metrics access
   curl http://<node-ip>:<metrics-nodeport>/metrics
   ```
