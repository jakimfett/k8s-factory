# Echo Server Swarm with Terraform

This directory contains Terraform code to deploy a configurable k8s control plane for stress testing and infrastructure learning.

## Usage

1. Initialize Terraform:
   ```sh
   terraform init
   ```
2. Apply the configuration (creates the containers):
   ```sh
   terraform apply
   ```

5. Destroy the containers when done:
   ```sh
   terraform destroy
   ```
