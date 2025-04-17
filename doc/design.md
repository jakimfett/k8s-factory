# Abstract Design Document: Learning Kubernetes with IaC in Docker

## Objective
To provide a reproducible, infrastructure-as-code (IaC) based method for setting up a local Kubernetes cluster inside Docker containers, with the primary goal of facilitating hands-on Kubernetes learning.

## Approach
- Use a tool (e.g., KinD or K3d) to orchestrate Kubernetes clusters within Docker containers.
- Define cluster configuration and setup steps as code (YAML, scripts, or declarative configs).
- Ensure the process is easily repeatable on different workstations with minimal prerequisites.

## Key Components
- **Docker**: Container runtime for hosting cluster nodes.
- **Cluster Orchestration Tool**: KinD (Kubernetes in Docker) or K3d (K3s in Docker).
- **Configuration as Code**: All cluster definitions and setup steps are stored in version-controlled files.

## Workflow Overview
1. Install Docker and the chosen orchestration tool.
2. Use provided configuration/code to spin up a Kubernetes cluster.
3. Interact with the cluster using `kubectl` for learning and experimentation.

## Design Goals
- Simplicity: Minimize steps and prerequisites.
- Portability: Run on any workstation with Docker.
- Transparency: All setup logic is visible and modifiable.
- Extensibility: Easy to add nodes, change versions, or customize networking.

---

# Overview of Logical Parts of Kubernetes

Kubernetes is a container orchestration system composed of several logical components:

## Control Plane Components
- **API Server**: The front end for the Kubernetes control plane. All commands (from users or other components) go through the API server.
- **etcd**: A distributed key-value store that holds all cluster data/state.
- **Controller Manager**: Runs controllers that handle routine tasks (e.g., node management, replication).
- **Scheduler**: Assigns newly created pods to nodes based on resource requirements and constraints.

## Node Components
- **Kubelet**: An agent running on each node, ensuring containers are running as specified.
- **Kube Proxy**: Maintains network rules on nodes, enabling communication to/from pods.
- **Container Runtime**: The software responsible for running containers (e.g., Docker, containerd).

## Application Layer (User Workloads)
- **Pods**: The smallest deployable units, which can hold one or more containers.
- **ReplicaSets, Deployments, StatefulSets, DaemonSets**: Controllers for managing pods.
- **Services**: Define networking and load balancing for accessing pods.
- **ConfigMaps & Secrets**: Store configuration data and sensitive information.
- **Namespaces**: Provide virtual clusters within a physical cluster for isolation.

## "K8s" vs. "Kubernetes" vs. the Tool
- **Kubernetes** is the full name of the system.
- **K8s** is simply a numeronym (K + 8 letters + s) and is used as a shorthand for “Kubernetes.” It is not a distinct tool or project.
- There is no official CLI tool called “k8s.” The main command-line tool for interacting with Kubernetes clusters is `kubectl`.

**Summary:**
“K8s” and “Kubernetes” refer to the same system; “K8s” is just an abbreviation. The tool you use to manage Kubernetes is `kubectl`.

---

# Echo Server Swarm Plan

To stress test and optimize the Terraform and Kubernetes cluster, a swarm of lightweight hashicorp/http-echo containers will be deployed. Each container will run an independent HTTP echo server, exposing a unique port for external access. The swarm size will be configurable, allowing for scalability and performance testing.

**Objectives:**
- Deploy multiple hashicorp/http-echo containers using Terraform (and later Kubernetes).
- Expose each container on a unique port for easy access and testing.
- Use the swarm to test networking, scaling, and resource limits of the infrastructure.
- Optionally, configure cross-container communication for advanced stress tests.

This setup provides a controlled, reproducible way to benchmark and experiment with both infrastructure-as-code and Kubernetes orchestration.

---

# Design Decision: Service Discovery via Environment Variables

To ensure that configuration is always authoritative and up-to-date, all service discovery and inter-service communication details (such as the list of echo server addresses) are passed to the aggregator exclusively via environment variables. This approach avoids static configuration, prevents caching or stale values, and ensures that the aggregator receives its configuration dynamically at runtime from the orchestrator (Terraform/Docker).

- **Why:** Environment variables are the most portable and infrastructure-agnostic way to inject configuration, supporting both local Docker and future Kubernetes deployments.
- **How:** Terraform constructs the list of echo server URLs and injects them as the `ECHO_URLS` environment variable into the aggregator container.
- **Result:** The aggregator always uses the current, authoritative configuration provided by the infrastructure layer, with no hardcoded or cached values in the application code.

---

# Project Structure Design

The project follows a multi-service architecture with clear separation between application code and infrastructure code:

```
kubernetes-windsurf/
├── services/           # Application services
│   ├── aggregator/     # Rust aggregator service
│   │   ├── src/        # Rust source code
│   │   ├── Cargo.toml  # Rust dependencies
│   │   ├── Dockerfile  # Container build definition
│   │   └── README.md   # Service documentation
│   └── metrics/        # Metrics collection and visualization
│       ├── prometheus/ # Prometheus configuration
│       │   ├── prometheus.yml # Scrape configuration
│       │   └── Dockerfile     # Prometheus container setup
│       ├── grafana/    # Optional visualization (conditionally deployed)
│       │   ├── provisioning/  # Dashboards and datasources
│       │   └── Dockerfile     # Grafana container setup
│       ├── docker-compose.yml # Local development setup
│       └── README.md   # Metrics service documentation
└── infrastructure/     # Infrastructure code
    ├── terraform/      # Terraform configuration
    │   ├── main.tf     # Main Terraform configuration
    │   ├── metrics.tf  # Metrics infrastructure
    │   └── variables.tf # Terraform variables
    └── kubernetes/     # Future Kubernetes manifests
```

**Design Rationale:**

1. **Separation of Concerns**: Application code (services) is separate from infrastructure code, allowing independent development cycles and clear responsibilities.

2. **Scalability**: The structure supports adding multiple services while maintaining organization.

3. **Infrastructure as Code**: All infrastructure components (Docker, Terraform, Kubernetes) are defined as code in dedicated directories.

4. **Migration Path**: The structure supports the planned migration from Docker/Terraform to Kubernetes by providing dedicated spaces for both configurations.

5. **Documentation**: Each component includes its own documentation, with project-wide design decisions captured in this document.

---

# Metrics Service Design

## Overview
The metrics service provides comprehensive monitoring capabilities for the Kubernetes Windsurf project. It follows a layered architecture that separates metrics collection (Prometheus) from visualization (Grafana), with the latter being optional and configurable.

## Design Principles

1. **Separation of Concerns**
   - **Collection Layer**: Always-on Prometheus instance for metrics collection
   - **Visualization Layer**: Optional Grafana instance for dashboard visualization

2. **Dynamic Service Discovery**
   - Uses Docker service discovery to automatically detect echo servers
   - No hardcoded service references, supporting dynamic scaling
   - Future-compatible with Kubernetes service discovery mechanisms

3. **Layered Monitoring Approach**
   - **Application Metrics**: Detailed metrics from the aggregator service (request counts, response times)
   - **Infrastructure Health**: Basic up/down monitoring of echo servers

4. **Infrastructure as Code**
   - All metrics configuration defined in code (Prometheus config, Grafana dashboards)
   - Terraform-managed deployment with conditional visualization

## Implementation Details

### Aggregator Metrics
The aggregator service is instrumented with Prometheus metrics using the `prometheus` and `lazy_static` Rust crates. It exposes:

- Request counters by endpoint (`aggregator_requests_total`)
- Response time histograms by echo server (`aggregator_response_time_ms`) with buckets from 5ms to 1000ms

### Service Discovery
Prometheus uses Docker socket access to automatically discover and monitor echo servers:

```yaml
docker_sd_configs:
  - host: unix:///var/run/docker.sock
    filters:
      - name: name
        values: ['echo-.*']
```

This approach allows for dynamic scaling of echo servers without configuration changes.

### Visualization
Grafana provides pre-configured dashboards for visualizing the collected metrics. It is conditionally deployed based on the `enable_visualization` Terraform variable, allowing for a lightweight deployment when visualization is not needed.

---

# Test-Driven Development Infrastructure

## Overview
The project follows a test-driven development (TDD) approach with comprehensive test scripts to validate functionality across multiple layers of the application. This ensures reliability, maintainability, and facilitates the future migration to Kubernetes.

## Design Principles

1. **Automation First**
   - All tests are fully automated via shell scripts
   - Designed for CI/CD pipeline integration
   - Consistent output format with clear pass/fail indicators

2. **Comprehensive Coverage**
   - Tests span from container management to service functionality
   - Validates both basic connectivity and advanced features
   - Ensures all critical paths are covered

3. **Environment Verification**
   - Tests include environment setup validation
   - Verifies container lifecycle management
   - Confirms required dependencies and network connectivity

4. **Metrics Validation**
   - Dedicated tests for metrics endpoint availability
   - Validates metric types and Prometheus compatibility
   - Ensures metrics are consistently available across environments

## Implementation Details

### Test Script Architecture
The primary test script (`test_aggregator.sh`) is organized into logical test suites:

1. **Debug Script Functionality Tests**
   - Validates container start/stop/restart capabilities
   - Ensures clean environment setup and teardown

2. **Aggregator Online Status Tests**
   - Verifies aggregator container health
   - Confirms HTTP endpoint availability
   - Checks container health status

3. **Echo Server Connectivity Tests**
   - Validates all echo servers are running
   - Confirms aggregator connects to 100% of echo servers
   - Verifies response content from echo servers

4. **Metrics Availability Tests**
   - Confirms metrics endpoint accessibility
   - Validates presence of required metrics
   - Verifies metrics follow Prometheus format

### Dependencies
The test infrastructure relies on specific tools to enable robust testing:

- **jq**: JSON processor for structured testing of API responses
  - Enables type-aware validation of aggregator responses
  - Provides reliable array operations for checking echo server connectivity
  - Allows for JSON path expressions to validate response content
  
- **curl**: For HTTP endpoint testing
- **docker**: For container management and inspection

### Integration with Development Workflow
Test scripts are designed to be run at multiple stages of development:

1. **Local Development**: During active development to verify changes
2. **Pre-commit Testing**: Before committing code to ensure quality
3. **CI/CD Pipeline**: As part of automated testing in CI/CD
4. **Deployment Validation**: After deployment to verify environment setup

The test-driven approach facilitates the future migration to Kubernetes by establishing clear expectations for service behavior and providing a foundation for Kubernetes-specific tests.
