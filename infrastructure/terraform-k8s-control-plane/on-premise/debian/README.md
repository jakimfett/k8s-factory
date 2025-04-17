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

## Usage

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
