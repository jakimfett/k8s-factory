# Echo Server Swarm with Terraform

This directory contains Terraform code to deploy a configurable swarm of lightweight hashicorp/http-echo containers for stress testing and infrastructure learning.

## Prerequisites
- Docker
- Terraform

## Usage

1. Initialize Terraform:
   ```sh
   terraform init
   ```
2. Apply the configuration (creates the containers):
   ```sh
   terraform apply
   ```
3. Access the echo servers:
   - http://localhost:8081
   - http://localhost:8082
   - http://localhost:8083
   - ... (depending on the swarm size)

4. Change the number of containers by editing the `echo_count` variable in `main.tf`.

5. Destroy the containers when done:
   ```sh
   terraform destroy
   ```
