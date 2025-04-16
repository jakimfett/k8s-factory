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
