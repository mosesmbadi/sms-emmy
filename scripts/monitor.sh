#!/bin/bash

# Simple monitoring script for SMS Emmy application
# Usage: ./monitor.sh [logs|stats|health|all]

COMMAND=${1:-all}

echo "🔍 SMS Emmy Monitoring Tool"
echo "=========================="

show_health() {
    echo ""
    echo "🏥 Health Status:"
    echo "-----------------"
    curl -s http://localhost:80/health | jq '.' 2>/dev/null || curl -s http://localhost:80/health
}

show_stats() {
    echo ""
    echo "📊 Application Statistics:"
    echo "-------------------------"
    curl -s http://localhost:80/metrics | jq '.summary' 2>/dev/null || curl -s http://localhost:80/metrics
}

show_logs() {
    echo ""
    echo "📋 Recent Application Logs:"
    echo "---------------------------"
    docker logs --tail 20 sms-api 2>/dev/null || echo "❌ Container not found or not running"
}

show_docker_status() {
    echo ""
    echo "🐳 Docker Container Status:"
    echo "---------------------------"
    docker ps --filter name=sms-api --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

show_system_resources() {
    echo ""
    echo "💻 System Resources:"
    echo "-------------------"
    echo "Memory Usage:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | grep sms-api || echo "Container not found"
    
    echo ""
    echo "Disk Usage:"
    df -h / | tail -1 | awk '{print "Available: " $4 " / " $2 " (" $5 " used)"}'
}

case $COMMAND in
    "health")
        show_health
        ;;
    "stats")
        show_stats
        ;;
    "logs")
        show_logs
        ;;
    "docker")
        show_docker_status
        ;;
    "resources")
        show_system_resources
        ;;
    "all")
        show_health
        show_stats
        show_docker_status
        show_system_resources
        show_logs
        ;;
    *)
        echo "Usage: $0 [health|stats|logs|docker|resources|all]"
        echo ""
        echo "Commands:"
        echo "  health     - Show application health status"
        echo "  stats      - Show message processing statistics"
        echo "  logs       - Show recent application logs"
        echo "  docker     - Show Docker container status"
        echo "  resources  - Show system resource usage"
        echo "  all        - Show everything (default)"
        exit 1
        ;;
esac

echo ""
echo "✅ Monitoring complete at $(date)"
echo ""
echo "🌐 Access monitoring dashboard: http://$(curl -s ifconfig.me)/monitoring"
