#!/bin/bash

# Quick deployment script for monitoring stack
set -euo pipefail

echo "🚀 Deploying SMS Application Monitoring Stack..."

# Create necessary directories
echo "📁 Creating monitoring directories..."
mkdir -p monitoring/grafana/{provisioning/{datasources,dashboards},dashboards}
mkdir -p logs

# Start the monitoring stack
echo "🔧 Starting monitoring services..."
if docker-compose -f docker-compose.monitoring.yml up -d; then
    echo "✅ Monitoring stack deployed successfully!"
    echo ""
    echo "📊 Access your monitoring tools:"
    echo "  • Grafana Dashboard: http://$(hostname -I | awk '{print $1}'):3000"
    echo "    Username: admin"
    echo "    Password: admin123"
    echo ""
    echo "  • Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
    echo "  • Alertmanager: http://$(hostname -I | awk '{print $1}'):9093"
    echo ""
    echo "🔍 Waiting for services to be ready..."
    
    # Wait for services to be healthy
    for i in {1..30}; do
        if curl -f -s "http://localhost:3000/api/health" >/dev/null 2>&1; then
            echo "✅ Grafana is ready!"
            break
        fi
        echo "  ⏳ Attempt $i/30: Waiting for Grafana..."
        sleep 10
    done
    
    echo ""
    echo "📋 Next steps:"
    echo "1. Open Grafana dashboard and verify data is flowing"
    echo "2. Configure alert notifications in monitoring/alertmanager.yml"
    echo "3. Set up incident response: ./scripts/incident-response.sh monitor"
    echo ""
    echo "🆘 For incident response:"
    echo "  ./scripts/incident-response.sh health    # Check application health"
    echo "  ./scripts/incident-response.sh restart   # Restart application"
    echo "  ./scripts/incident-response.sh diagnose  # Collect diagnostics"
else
    echo "❌ Failed to deploy monitoring stack"
    echo "Check the logs with: docker-compose -f docker-compose.monitoring.yml logs"
    exit 1
fi
