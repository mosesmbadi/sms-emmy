# System Documentation for SMS Emmy Application

This document provides an overview of the SMS Emmy application, detailing its core components, architectural approach, and operational aspects.

## 1. API Component

**Purpose:** The `api` component serves as the backend for the SMS Emmy application. It handles CSV file uploads, processes contact data, formats messages, and manages message status storage. It also exposes health checks and Prometheus metrics.

**Approach:**
*   **Framework:** Built using Flask, a lightweight Python web framework.
*   **Database:** Uses SQLite for local message storage, managed by Flask-SQLAlchemy.
*   **Functionality:**
    *   **CSV Upload (`/upload`):** Accepts CSV files containing contact information and a message template. It parses the CSV, formats messages, validates phone numbers using `phonenumbers` library, and stores messages in the database.
    *   **Message Creation (`/messages`):** An alternative endpoint to create messages via JSON payload.
    *   **Health Check (`/health`):** Provides an endpoint to check the application's health, including database connectivity and message statistics.
    *   **Metrics (`/metrics`):** Exposes Prometheus metrics for monitoring application performance and status.
    *   **Rate Limiting:** Implements rate limiting using `Flask-Limiter` to prevent abuse.
    *   **Templating:** Uses Jinja2 templates for basic web pages (`index.html`, `results.html`, `monitoring.html`).
*   **Containerization:** Dockerfiles (`Dockerfile`, `Dockerfile.local`) are provided for building and running the application in Docker containers.
*   **Dependencies:** Managed via `requirements.txt` (Flask, phonenumbers, SQLAlchemy, Flask-SQLAlchemy, Flask-Limiter, prometheus-client).

**Challenges/Considerations:**
*   **Scalability:** The current SQLite database might become a bottleneck for high-volume applications. A more robust database solution (e.g., PostgreSQL, MySQL) would be necessary for production at scale.
*   **Asynchronous Processing:** Message sending is currently synchronous. For a real-world SMS application, integrating a message queue (e.g., RabbitMQ, Kafka) and a worker system would be crucial for asynchronous processing, retries, and handling high message throughput.
*   **Error Handling:** While basic error handling is present, more sophisticated error reporting and alerting mechanisms could be integrated.
*   **Security:** Input validation and sanitization should be thoroughly reviewed, especially for message templates, to prevent injection attacks.

## 2. Monitoring Component

**Purpose:** The `monitoring` component provides a comprehensive solution for observing the health, performance, and operational status of the SMS Emmy application. It leverages Prometheus for metrics collection, Alertmanager for alert management, and Grafana for visualization.

**Approach:**
*   **Prometheus:**
    *   **Configuration (`prometheus.yml`):** Scrapes metrics from the `sms-api` service (exposed via `/metrics`), `node-exporter` (for host-level metrics), and itself.
    *   **Alert Rules (`alert_rules.yml`):** Defines various alert conditions based on application health, error rates, database connectivity, system resource usage (CPU, memory, disk), message processing time, and rate limit exceedances.
*   **Alertmanager:**
    *   **Configuration (`alertmanager.yml`):** Manages the routing, grouping, and silencing of alerts. It's configured to send critical alerts via email and Slack webhook, and warning alerts via email.
    *   **Receivers:** Defines different receivers for alerts based on severity.
*   **Grafana:**
    *   **Datasource Provisioning (`grafana/provisioning/datasources/prometheus.yml`):** Automatically configures Prometheus as a data source within Grafana.
    *   **Dashboard Provisioning (`grafana/provisioning/dashboards/dashboards.yml`):** Automatically loads the `sms-dashboard.json` into Grafana.
    *   **Dashboard (`grafana/dashboards/sms-dashboard.json`):** Provides pre-configured visualizations for key application metrics, including application health, service status, CPU usage, and memory usage.

**Challenges/Considerations:**
*   **Alert Fatigue:** Careful tuning of alert thresholds and grouping rules is essential to prevent alert fatigue.
*   **Notification Channels:** The current setup uses placeholders for email and Slack webhooks. These need to be configured with actual values for production use.
*   **Node Exporter:** The `prometheus.yml` expects a `node_exporter` service. This needs to be deployed on the host machine or as a sidecar container to collect system-level metrics.
*   **Dashboard Customization:** While a basic dashboard is provided, further customization might be needed to cover all relevant metrics and provide deeper insights.

## 3. Scripts Component

**Purpose:** The `scripts` directory contains various shell scripts designed to automate deployment, monitoring, and incident response procedures for the SMS Emmy application.

**Approach:**
*   **`deploy-monitoring.sh`:**
    *   **Functionality:** A quick deployment script for the monitoring stack (Prometheus, Grafana, Alertmanager) using `docker-compose`.
    *   **Steps:** Creates necessary directories, starts Docker services, waits for Grafana to be healthy, and provides access URLs and next steps.
    *   **Challenges:** Assumes `docker-compose.monitoring.yml` exists and is correctly configured. Requires Docker and Docker Compose to be installed on the host.
*   **`deploy-remote.sh`:** (Empty in the provided context)
    *   **Expected Functionality:** This script is likely intended for deploying the application to a remote server, possibly orchestrating Docker deployments or interacting with cloud provider APIs.
    *   **Challenges:** Needs implementation. Would involve SSH, SCP, and potentially remote Docker commands or cloud-specific deployment tools.
*   **`incident-response.sh`:**
    *   **Functionality:** An automated incident response playbook. It can monitor application health, restart the application, collect diagnostics, and handle specific incident types (e.g., `app_down`, `high_error_rate`, `resource_exhaustion`).
    *   **Features:** Logging, sending alert notifications via webhook, health checks, Docker container management, system resource collection.
    *   **Challenges:** Requires `docker-compose.prod.yml` for production deployment. Relies on `jq` for JSON parsing. The `ALERT_WEBHOOK_URL` environment variable needs to be set for notifications. The `monitor` command runs a continuous loop, which might need to be managed as a background service.
*   **`monitor.sh`:**
    *   **Functionality:** A simple command-line monitoring tool to display health status, application statistics, recent logs, Docker container status, and system resources.
    *   **Dependencies:** Uses `curl` and `jq` (optional for pretty printing JSON).
    *   **Challenges:** Assumes the application is running on `localhost:80` (or accessible via `localhost:5000` if not behind a proxy).

## 4. Terraform Component

**Purpose:** The `terraform` component defines and provisions the cloud infrastructure required to host the SMS Emmy application on AWS using Infrastructure as Code (IaC) principles.

**Approach:**
*   **Provider:** Configured to use the AWS provider (`hashicorp/aws`) and `tls` provider for SSH key generation.
*   **Network:**
    *   **VPC:** Creates a Virtual Private Cloud (VPC) with a specified CIDR block.
    *   **Internet Gateway (IGW):** Provides internet connectivity for the VPC.
    *   **Public Subnet:** Creates a public subnet within the VPC, mapping public IPs on launch.
    *   **Route Table:** Configures a route table for the public subnet to route traffic through the IGW.
*   **Security:**
    *   **Security Group:** Defines a security group (`sms_emmy_sg`) allowing inbound SSH (port 22), HTTP (port 80), HTTPS (port 443), and Flask application (port 5000) traffic from anywhere, and all outbound traffic.
    *   **SSH Key Pair:** Generates an RSA SSH key pair and creates an AWS Key Pair for secure access to the EC2 instance.
*   **Compute:**
    *   **EC2 Instance:** Provisions an Ubuntu 22.04 LTS EC2 instance (`t3.micro` by default).
    *   **User Data (`cloud-init.yml`):** Uses `cloud-init` to automate initial setup on the EC2 instance, including:
        *   Updating packages.
        *   Installing Docker and Docker Compose.
        *   Adding the `ubuntu` user to the `docker` group.
        *   Creating an application directory and a `messages.db` file.
        *   (Optional) Installing Nginx.
    *   **Elastic IP (EIP):** Allocates a static public IP address and associates it with the EC2 instance.
*   **Variables (`variables.tf`):** Defines configurable parameters such as AWS region, project name, instance type, admin username, and common tags.
*   **Outputs (`outputs.tf`):** Exports important information after deployment, such as VPC ID, public IP, SSH connection command, application URL, and the generated SSH private key (marked as sensitive).
*   **Deployment Scripts:**
    *   **`deploy.sh`:** A wrapper script to initialize, validate, plan, and apply the Terraform configuration. It includes checks for Terraform and AWS CLI installation, prompts for `terraform.tfvars` review, and provides a deployment summary.
    *   **`destroy.sh`:** A script to destroy all infrastructure provisioned by Terraform, with a confirmation prompt to prevent accidental deletion.

**Challenges/Considerations:**
*   **Security Group Rules:** The current security group allows SSH, HTTP, HTTPS, and Flask app access from `0.0.0.0/0`. For production, these should be restricted to known IP ranges.
*   **`terraform.tfvars`:** The `deploy.sh` script prompts the user to review `terraform.tfvars`. It's crucial to customize this file with appropriate values (e.g., `aws_region`, `instance_type`, `admin_username`).
*   **State Management:** Terraform state is managed locally by default. For team collaboration and production environments, remote state management (e.g., S3 backend) should be configured.
*   **Application Deployment:** The `cloud-init.yml` sets up Docker but doesn't deploy the SMS Emmy application itself. A separate deployment step (e.g., using `deploy-remote.sh` or a CI/CD pipeline) would be needed to get the application code onto the EC2 instance and run it.
*   **Cost Management:** `t3.micro` is a free-tier eligible instance type, but costs can accrue if not managed.
*   **High Availability:** The current setup provisions a single EC2 instance. For high availability, an Auto Scaling Group and Load Balancer would be required.
*   **Database Persistence:** The `messages.db` is created on the EC2 instance. If the instance is terminated, the data will be lost. A managed database service (e.g., AWS RDS) should be used for persistent data storage.
