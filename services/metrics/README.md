# Metrics Service

This service provides monitoring capabilities for the Kubernetes Windsurf project using Prometheus and Grafana.

## Components

### Prometheus
Prometheus is responsible for collecting and storing metrics from the various services in the project:
- Aggregator service metrics
- Echo server metrics (automatically discovered)
- Prometheus's own metrics

### Grafana
Grafana provides visualization dashboards for the metrics collected by Prometheus. It is designed to be optional and can be enabled or disabled as needed.

## Monitoring Architecture

The metrics service uses a layered approach to monitoring:

### 1. Aggregator Metrics
The aggregator service exposes detailed Prometheus metrics about:
- Request counts to different endpoints
- Response times from each echo server
- Other operational metrics

These metrics provide comprehensive insights into the system's performance without requiring modifications to the echo servers themselves.

### 2. Echo Server Health Checks
Prometheus uses Docker service discovery to automatically detect and perform basic health checks on echo servers:

- **Dynamic Scaling**: As echo servers are added or removed, Prometheus automatically updates its targets
- **Simple Health Monitoring**: Basic up/down monitoring without requiring metrics instrumentation
- **Future Kubernetes Compatibility**: This approach can be easily migrated to Kubernetes service discovery

This architecture follows the principle of separation of concerns - the aggregator handles detailed metrics collection while Prometheus handles basic health monitoring.

## Usage

### Metrics Collection Only
By default, only Prometheus is started to collect metrics without visualization. This keeps the resource usage low while still capturing all monitoring data.

### Full Visualization Stack
When visualization is needed, Grafana can be enabled to provide dashboards for the collected metrics.

## Configuration

### Prometheus
The Prometheus configuration is defined in `prometheus.yml` and includes scrape configurations for all services in the project.

### Grafana
Grafana is configured to connect to the Prometheus data source automatically when started.

## Infrastructure Integration

This service is designed to work with both Docker/Terraform and Kubernetes, supporting the project's migration path.
