# SMS Application Monitoring & Incident Response

This document outlines the comprehensive monitoring, alerting, and incident response system for the SMS application.

## 🚨 **Alert System Overview**

### **Critical Alerts (Immediate Response Required)**

- **Application Down**: Service not responding for >30 seconds
- **Database Connection Failure**: Cannot connect to database for >1 minute
- **High CPU/Memory/Disk**: System resources >85-90% for >5 minutes

### **Warning Alerts (Monitor & Investigate)**

- **High Error Rate**: >5% error rate for >2 minutes
- **Slow Processing**: Message processing >30 seconds
- **Rate Limit Exceeded**: >10 rate limit hits in 5 minutes
- **High Message Failure Rate**: >10% message failures

## 📊 **Dashboard Access**

After deploying the monitoring stack:

- **Grafana Dashboard**: `http://your-server:3000`

  - Username: `admin`
  - Password: `admin123`
  - Main dashboard: "SMS Application Dashboard"

- **Prometheus Metrics**: `http://your-server:9090`
- **Alertmanager**: `http://your-server:9093`

## 🔧 **Quick Setup**

### 1. Deploy Monitoring Stack

```bash
# On your production server
cd ~/sms-emmy

# Download monitoring configuration
wget https://raw.githubusercontent.com/mosesmbadi/sms-emmy/main/docker-compose.monitoring.yml

# Create monitoring directories
mkdir -p monitoring/grafana/{provisioning/{datasources,dashboards},dashboards}

# Download all monitoring configs... (or copy from repo)

# Start monitoring stack
docker-compose -f docker-compose.monitoring.yml up -d
```

### 2. Configure Alerts

Edit `monitoring/alertmanager.yml`:

```yaml
# Update with your email and Slack webhook
receivers:
  - name: "critical-alerts"
    email_configs:
      - to: "your-email@domain.com" # ← Change this
    webhook_configs:
      - url: "YOUR_SLACK_WEBHOOK_URL" # ← Add your Slack webhook
```

### 3. Setup Incident Response

```bash
# Copy incident response script
cp scripts/incident-response.sh ~/sms-emmy/
chmod +x ~/sms-emmy/incident-response.sh

# Set up monitoring daemon (optional)
# Add to crontab for automatic monitoring
echo "*/5 * * * * /home/ubuntu/sms-emmy/incident-response.sh health" | crontab -
```

## 🚨 **Incident Response Procedures**

### **Automated Response**

The system automatically handles common incidents:

```bash
# Check application health
./incident-response.sh health

# Start monitoring daemon
./incident-response.sh monitor

# Force restart application
./incident-response.sh restart

# Handle specific incident
./incident-response.sh handle app_down
```

### **Manual Response Procedures**

#### **Application Down**

1. **Check Status**:

   ```bash
   curl http://localhost:5000/health
   docker ps
   ```

2. **View Logs**:

   ```bash
   docker logs sms-api
   ```

3. **Restart Service**:

   ```bash
   ./incident-response.sh restart
   ```

4. **Escalate if needed**:
   - Check system resources
   - Review application logs
   - Contact development team

#### **High Error Rate**

1. **Check Error Patterns**:

   ```bash
   curl http://localhost:5000/metrics | grep error
   ```

2. **Review Recent Changes**:

   - Check recent deployments
   - Review application logs

3. **Rollback if Needed**:
   ```bash
   # Deploy previous version
   docker tag ghcr.io/mosesmbadi/sms-emmy:previous ghcr.io/mosesmbadi/sms-emmy:latest
   ./incident-response.sh restart
   ```

#### **Resource Exhaustion**

1. **Immediate Cleanup**:

   ```bash
   docker system prune -f
   ```

2. **Identify Resource Hogs**:

   ```bash
   top
   df -h
   docker stats
   ```

3. **Scale Resources**:
   - Increase EC2 instance size
   - Add disk space
   - Optimize application

## 📱 **Alert Channels**

### **Slack Integration**

1. Create Slack webhook: https://api.slack.com/messaging/webhooks
2. Add webhook URL to `monitoring/alertmanager.yml`
3. Restart alertmanager: `docker-compose -f docker-compose.monitoring.yml restart alertmanager`

### **Email Alerts**

Configure SMTP settings in `monitoring/alertmanager.yml`:

```yaml
global:
  smtp_smarthost: "smtp.gmail.com:587"
  smtp_from: "alerts@yourdomain.com"
  smtp_auth_username: "your-email@gmail.com"
  smtp_auth_password: "your-app-password"
```

### **SMS Alerts (Advanced)**

For critical alerts, integrate with services like:

- **Twilio**: SMS notifications
- **PagerDuty**: Incident management
- **OpsGenie**: On-call management

## 📈 **Key Metrics to Monitor**

### **Application Metrics**

- **Uptime**: `up{job="sms-api"}`
- **Response Time**: `flask_http_request_duration_seconds`
- **Error Rate**: `rate(flask_http_request_exceptions_total[5m])`
- **Message Processing**: `sms_messages_total_total`

### **System Metrics**

- **CPU Usage**: `100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
- **Memory Usage**: `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100`
- **Disk Usage**: `(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100`

### **Business Metrics**

- **Messages Sent**: Total successful messages
- **Failure Rate**: Percentage of failed messages
- **Processing Time**: Average time to process messages

## 🔄 **Monitoring Stack Components**

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Dashboards and visualization
- **Alertmanager**: Alert routing and notifications
- **Node Exporter**: System metrics collection
- **Flask App**: Custom application metrics

## 🆘 **Emergency Contacts**

```bash
# Primary On-Call
Name: [Your Name]
Phone: [Your Phone]
Email: [Your Email]
Slack: @yourusername

# Secondary On-Call
Name: [Backup Person]
Phone: [Backup Phone]
Email: [Backup Email]

# Development Team Lead
Email: dev-team@yourcompany.com
```

## 📋 **Runbook Checklist**

### **Incident Response Checklist**

- [ ] Alert received and acknowledged
- [ ] Initial assessment performed
- [ ] Severity determined (Critical/Warning/Info)
- [ ] Appropriate response initiated
- [ ] Stakeholders notified
- [ ] Resolution implemented
- [ ] Post-incident review scheduled

### **Daily Health Checks**

- [ ] Application responding to health checks
- [ ] All containers running
- [ ] Resource utilization within normal ranges
- [ ] No critical alerts in last 24 hours
- [ ] Backup and log rotation working

## 🎯 **SLAs & SLOs**

### **Service Level Objectives**

- **Availability**: 99.9% uptime (8.7 hours downtime/year)
- **Response Time**: <2 seconds for 95% of requests
- **Error Rate**: <1% of all requests
- **Recovery Time**: <5 minutes for automated recovery

### **Alert Response Times**

- **Critical**: 5 minutes
- **Warning**: 30 minutes
- **Info**: 24 hours
