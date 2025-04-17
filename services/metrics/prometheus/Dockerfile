FROM prom/prometheus:latest

# Copy configuration
COPY prometheus.yml /etc/prometheus/prometheus.yml

EXPOSE 9090

# Docker socket is mounted in docker-compose.yml and Terraform for service discovery
