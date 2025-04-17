terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
    ssh = {
      source  = "loafoe/ssh"
      version = "~> 2.6.0"
    }
  }
  required_version = ">= 1.0.0"
}

# SSH connection details for remote server
provider "ssh" {
  host     = var.server_ip
  user     = var.ssh_user
  private_key = file(var.ssh_private_key_path)
}

# Install containerd runtime
resource "null_resource" "install_containerd" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.server_ip
  }

  provisioner "remote-exec" {
    inline = [
      # Install containerd
      "sudo apt-get install -y containerd.io",
      
      # Configure containerd
      "sudo mkdir -p /etc/containerd",
      "sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null",
      
      # Configure systemd cgroup driver
      "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml",
      
      # Enable and start containerd
      "sudo systemctl restart containerd",
      "sudo systemctl enable containerd",
      
      # Configure kernel modules for containerd/Kubernetes
      "sudo modprobe overlay",
      "sudo modprobe br_netfilter",
      
      # Set up required sysctl params
      "echo 'net.bridge.bridge-nf-call-iptables = 1' | sudo tee -a /etc/sysctl.d/99-kubernetes-cri.conf",
      "echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-kubernetes-cri.conf",
      "echo 'net.bridge.bridge-nf-call-ip6tables = 1' | sudo tee -a /etc/sysctl.d/99-kubernetes-cri.conf",
      "sudo sysctl --system"
    ]
  }
}

# Install Kubernetes components
resource "null_resource" "install_kubernetes" {
  depends_on = [null_resource.install_containerd]
  
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.server_ip
  }

  provisioner "remote-exec" {
    inline = [
      # Disable swap (required for Kubernetes)
      "sudo swapoff -a",
      "sudo sed -i '/ swap / s/^/#/' /etc/fstab",
      
      # Install prerequisites
      "sudo apt-get update",
      "sudo apt-get install -y apt-transport-https ca-certificates curl",
      
      # Add Kubernetes apt repository
      "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      "echo \"deb https://apt.kubernetes.io/ kubernetes-xenial main\" | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      
      # Install Kubernetes components
      "sudo apt-get update",
      "sudo apt-get install -y kubelet=${var.kubernetes_version}-00 kubeadm=${var.kubernetes_version}-00 kubectl=${var.kubernetes_version}-00",
      "sudo apt-mark hold kubelet kubeadm kubectl"
    ]
  }
}

# Initialize Kubernetes control plane
resource "null_resource" "init_kubernetes" {
  depends_on = [null_resource.install_kubernetes]
  
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.server_ip
  }

  # Render the kubeadm config template
  provisioner "local-exec" {
    command = "envsubst < kubeadm-config.yaml.tpl > kubeadm-config.yaml"
    environment = {
      kubernetes_version = var.kubernetes_version
      pod_cidr = var.pod_cidr
      service_cidr = var.service_cidr
      server_ip = var.server_ip
    }
    working_dir = "/Users/jakimfett/hub/dev/kubernetes-windsurf/infrastructure/terraform-k8s-control-plane/on-premise/debian"
  }

  # Upload the kubeadm config file
  provisioner "file" {
    source      = "/Users/jakimfett/hub/dev/kubernetes-windsurf/infrastructure/terraform-k8s-control-plane/on-premise/debian/kubeadm-config.yaml"
    destination = "/tmp/kubeadm-config.yaml"
  }

  provisioner "remote-exec" {
    inline = [

      # Initialize control plane with the configuration file
      "sudo kubeadm init --config=/tmp/kubeadm-config.yaml --upload-certs",
      
      # Configure kubectl for the user (note: .kube directory was pre-created in setup_k8s_admin.sh)
      "sudo cp -i /etc/kubernetes/admin.conf /home/${var.ssh_user}/.kube/config",
      "sudo chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/.kube/config",
      "cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      
      # Install Calico network plugin
      "kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml",
      
      # Allow scheduling on control plane (for single-node clusters)
      "kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true",
      "kubectl taint nodes --all node-role.kubernetes.io/master- || true",
      
      # Create the k8s-factory namespace
      "kubectl create namespace k8s-factory || true"
    ]
  }
}

# Retrieve kubeconfig for local use
resource "null_resource" "retrieve_kubeconfig" {
  depends_on = [null_resource.init_kubernetes]
  
  provisioner "local-exec" {
    command = "mkdir -p ${var.kubeconfig_path} && scp -i ${var.ssh_private_key_path} ${var.ssh_user}@${var.server_ip}:~/.kube/config ${var.kubeconfig_path}/config-debian"
  }
}

# Output connection instructions
resource "null_resource" "output_connection_info" {
  depends_on = [null_resource.retrieve_kubeconfig]
  
  provisioner "local-exec" {
    command = "echo \"Kubernetes control plane successfully deployed on ${var.server_ip}. Use 'export KUBECONFIG=${var.kubeconfig_path}/config-debian' to connect.\""
  }
}

# Remove temporary sudo permissions after successful deployment
resource "null_resource" "cleanup_temp_permissions" {
  depends_on = [null_resource.output_connection_info]
  
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.server_ip
  }

  provisioner "remote-exec" {
    inline = [
      "# Remove temporary sudo permissions",
      "sudo rm -f /etc/sudoers.d/terraform_temp",
      "echo 'Temporary sudo permissions removed. Now only Kubernetes-specific operations are passwordless.'"
    ]
  }
}
