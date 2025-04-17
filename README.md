# Kubernetes Windsurf

## Project Goal
To provide a hands-on, infrastructure-as-code learning environment for Kubernetes using Docker containers and Terraform. The project emphasizes experimentation, stress testing, and reproducibility across different workstations.

## Objectives
- Learn Kubernetes concepts and workflows using local, containerized clusters.
- Use Terraform to manage and scale lightweight application swarms (hashicorp/http-echo) for stress testing and optimization.
- Document all steps and configurations for repeatable, portable setups.

## Quickstart

1. **Install Prerequisites:**
   - [Docker](https://docs.docker.com/get-docker/)
   - [Terraform](https://developer.hashicorp.com/terraform/downloads)
   - [jq](https://jqlang.github.io/jq/download/) (for running tests)

2. **Use the Debug Script:**
   ```sh
   ./scripts/run_debug_containers.sh --start
   ```

3. **Deploy the Echo Server Swarm:**
   ```sh
   cd infrastructure/terraform
   terraform init
   terraform apply
   ```

4. **Access the Echo Servers:**
   - http://localhost:8081
   - http://localhost:8082
   - http://localhost:8083
   - ... (based on swarm size)

5. **Modify the Swarm Size:**
   - Edit the `echo_count` variable in `infrastructure/main.tf` and re-apply.

6. **Destroy the Swarm:**
   ```sh
   terraform destroy
   ```

7. **Run Tests:**
   ```sh
   ./scripts/test_aggregator.sh
   ```
   For individual tests, you can run:
   ```
   source scripts/test_aggregator.sh
   ```
   and then use functions like `run_test` and `run_all_tests` by name.

## Documentation
- See `doc/design.md` for architecture and design decisions.
- See `infrastructure/README.md` for detailed Terraform usage.
