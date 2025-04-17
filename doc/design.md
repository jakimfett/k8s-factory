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
k8s-factory/
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
The metrics service provides comprehensive monitoring capabilities for the k8s-factory project. It follows a layered architecture that separates metrics collection (Prometheus) from visualization (Grafana), with the latter being optional and configurable.

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
   - Configurable verbosity with minimal default output
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
The primary test script (`test_aggregator.sh`) is organized into logical test suites and features output verbosity control:

#### Verbosity Modes
- **Standard Mode**: Displays minimal output with progress dots and summary
- **Verbose Mode**: Provides detailed test output and container logs (activated with `-v` or `--verbose`)

#### Test Suites
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
- **source**: For running individual test functions
- **sh | bash**: For running the test script


### Integration with Development Workflow
Test scripts are designed to be run at multiple stages of development:

1. **Local Development**: During active development to verify changes
2. **Pre-commit Testing**: Before committing code to ensure quality
3. **CI/CD Pipeline**: As part of automated testing in CI/CD
4. **Deployment Validation**: After deployment to verify environment setup

The test-driven approach facilitates the future migration to Kubernetes by establishing clear expectations for service behavior and providing a foundation for Kubernetes-specific tests.

---

# Container Lifecycle Management and Error Handling

## Overview
A robust container lifecycle management strategy is implemented to ensure reliable operation in both development and production environments. The approach prioritizes fault detection, detailed error reporting, and graceful failure modes over silent failures or endless restart loops.

## Design Principles

1. **Fail Fast, Fail Loudly**
   - Containers detect and report issues quickly with clear error messages
   - Critical failures trigger immediate exit with detailed diagnostic information
   - All error states are accompanied by descriptive logs and emoji-highlighted warnings

2. **Resource Conflict Detection**
   - Containers explicitly check for port binding conflicts at startup
   - Network resource availability is verified before service initialization
   - DNS resolution and service discovery issues are proactively identified

3. **Self-Healing with Limits**
   - Services implement retry logic with exponential backoff for transient issues
   - Restart loops are detected and limited to prevent resource exhaustion
   - Container health is monitored via HTTP health checks and process monitoring

4. **Dependency Validation**
   - Required environment variables are validated at startup
   - Upstream service availability is verified before initialization
   - Explicit network connectivity tests ensure proper communication paths

## Implementation Details

### Startup Script Architecture
Each container includes a comprehensive startup wrapper script that performs important checks before launching the primary service:

1. **Network Environment Analysis**
   - IP configuration inspection
   - Open port verification
   - DNS resolution testing

2. **Port Conflict Detection**
   - Verification of required ports availability
   - Detailed error reporting for port conflicts
   - Network socket binding validation

3. **Dependency Connectivity Testing**
   - Echo server availability verification
   - Configurable retry attempts and backoff strategy
   - Graceful degradation when dependencies are unavailable

4. **Restart Loop Prevention**
   - Counter-based restart detection
   - Maximum restart thresholds
   - Extended diagnostic sleep periods for troubleshooting

### Health Check Implementation
- Dedicated `/health` HTTP endpoint in each service
- Process-level monitoring as fallback
- Docker HEALTHCHECK instructions with appropriate timing parameters

---

# Infrastructure Testing Strategy

## Overview
The project implements a comprehensive infrastructure testing strategy to ensure our Terraform configurations are correct, secure, and reliably deployable. This multi-layered approach validates infrastructure at several levels, from static code analysis to runtime verification.

## Design Principles

1. **Multi-layered Validation**
   - Static code analysis for syntax and best practices
   - Security scanning for vulnerabilities
   - Runtime testing for actual behavior
   - Native functionality tests for comprehensive validation

2. **Automation First**
   - All tests integrated into CI/CD pipeline
   - Pre-commit hooks for local validation
   - Reproducible test execution across environments

3. **Security by Design**
   - Proactive scanning for security vulnerabilities
   - Enforcement of security best practices
   - Regular auditing of configuration changes

4. **Infrastructure as Code Integrity**
   - Ensure infrastructure matches configuration
   - Prevent configuration drift
   - Validate expected resources are created correctly

---

# Kubernetes Migration Strategy

## Overview
A structured strategy for migrating from a Docker-based development environment to a Kubernetes-orchestrated production system, while preserving testing capabilities and infrastructure-as-code principles.

## High-Level Approach

We will use a hybrid approach that leverages the strengths of both Terraform and Kubernetes:

- Use Terraform to provision the Kubernetes control plane cluster regardless of deployment location (cloud, local, or on-premise)
- Once the control plane is established, Terraform hands off to Kubernetes for workload management
- Create a clear separation between infrastructure provisioning and application deployment

## Implementation Plan

1. **Infrastructure Organization**
   - Create a distinct Terraform project directory for control plane provisioning (`infrastructure/terraform-k8s-control-plane`)
   - Preserve the existing Terraform Docker setup by moving it to `infrastructure/testing-terraform-docker-cluster`
   - Maintain both environments to enable comparison testing throughout the migration

2. **Multi-Environment Support**
   - Create stubs for major cloud providers that offer Terraform-initiated managed Kubernetes services
   - Focus initial implementation on local (macOS) and on-premise (Debian) bare-metal deployments
   - Defer implementation of cloud-based providers that incur costs until the core functionality is perfected

3. **Kubernetes-Native Features Utilization**
   - Use Kubernetes for workload scaling based on demand metrics
   - Implement a management cluster optimized for managing a changing selection of microclusters
   - Migrate containerized services to Kubernetes-native deployment patterns

4. **CI/CD Integration**
   - Set up GitHub Actions workflows for the new Terraform/Kubernetes deployment pipeline
   - Fall back to existing Laminar-based build system at `build.functions.sh` if GitHub Actions require paid features

## Architectural Benefits

This approach:
1. Isolates our initial test environment from our production code development
2. Provides a comparison baseline until Kubernetes implementation reaches feature parity
3. Leverages Terraform's strengths in infrastructure provisioning while using Kubernetes for what it does best
4. Creates a clear separation of concerns between infrastructure and application layers
5. Maintains infrastructure-as-code principles throughout the entire stack

## File Structure

```
k8s-factory/
├── infrastructure/
│   ├── terraform-docker-cluster/     # Moved from current terraform/ 
│   └── terraform-k8s-control-plane/  # New cluster provisioning
│       ├── local/                    # macOS (minikube/kind)
│       ├── on-premise/               # Debian bare-metal
│       └── cloud-providers/          # Stubs for AWS, GCP, Azure
├── kubernetes/                       # K8s manifests
│   ├── base/                         # Common resources
│   │   ├── namespaces.yaml
│   │   ├── aggregator/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── configmap.yaml
│   │   └── echo-services/
│   │       └── statefulset.yaml
│   └── overlays/                     # Environment-specific changes
│       ├── dev/
│       └── prod/
└── .github/workflows/               # CI/CD workflows
    ├── test.yaml                     # Includes Terraform, shellcheck tests
    └── deploy.yaml                   # Environment deployment workflow
```

This structure follows GitOps best practices, enabling infrastructure-as-code principles while maintaining a clear separation between cluster provisioning (Terraform) and workload management (Kubernetes).

## Implementation Stack

### Configuration Validation
- **Terraform Validate**: Built-in syntax and consistency checking
- **Terraform Plan**: Preview changes and verify expected outcomes
- **TFLint**: Advanced linting for best practices enforcement

### Security Testing
- **Terrascan**: Security vulnerability scanning for infrastructure code
- **Custom Security Checks**: Project-specific security validations

### Runtime Testing
- **Serverspec**: Testing actual deployed infrastructure against specifications
- **HTTP/API Tests**: Validating service endpoints and behavior

### Comprehensive Testing
- **Terraform Testing Framework**: Native HCL-based tests for validating resources
- **Custom Test Scripts**: Targeted tests for specific project requirements

### CI/CD Integration
- **GitHub Actions**: Workflow automation for all test stages
- **Test Reporting**: Comprehensive reporting of test results
- **Deployment Gates**: Preventing deployments that don't pass tests

## Implementation Details

### GitHub Actions Workflow
The CI/CD pipeline includes the following stages:

1. **Validation Stage**
   - Run `terraform validate` and `terraform plan`
   - Execute TFLint with project-specific rules
   - Fail fast if configuration issues are detected

2. **Security Scanning Stage**
   - Run Terrascan against all Terraform files
   - Compare results against baseline/allowlist
   - Generate security reports

3. **Deployment Test Stage**
   - Apply configuration to test environment
   - Run Serverspec tests against deployed infrastructure
   - Verify all services are functioning correctly

4. **Native Testing Stage**
   - Execute Terraform Testing Framework tests
   - Validate specific resource properties and conditions
   - Ensure compliance with project standards

### Local Development Flow
Developers can run a subset of tests locally using:

1. Pre-commit hooks for validation and linting
2. Local test scripts for quick feedback
3. Docker-based testing environment for consistent results
