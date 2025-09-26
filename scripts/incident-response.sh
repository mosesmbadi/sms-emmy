#!/bin/bash

# Incident Response Playbook for SMS Application
# This script provides automated incident response procedures

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/sms-incident-response.log"
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Send alert notification
send_alert() {
    local severity="$1"
    local message="$2"
    
    log "ALERT [$severity]: $message"
    
    if [[ -n "$ALERT_WEBHOOK_URL" ]]; then
        curl -X POST "$ALERT_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"🚨 [$severity] SMS App Incident: $message\"}" \
            2>/dev/null || log "Failed to send webhook notification"
    fi
}

# Check application health
check_health() {
    local health_endpoint="http://localhost:5000/health"
    
    if curl -f -s "$health_endpoint" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Restart application
restart_application() {
    log "Attempting to restart SMS application..."
    
    cd "$SCRIPT_DIR"
    
    # Stop current containers
    docker-compose -f docker-compose.prod.yml down 2>/dev/null || true
    
    # Wait a moment
    sleep 5
    
    # Start containers
    if docker-compose -f docker-compose.prod.yml up -d; then
        log "Application restart initiated"
        
        # Wait for health check
        local attempts=0
        local max_attempts=12
        
        while [[ $attempts -lt $max_attempts ]]; do
            sleep 10
            if check_health; then
                log "Application is healthy after restart"
                send_alert "INFO" "Application successfully restarted and is healthy"
                return 0
            fi
            ((attempts++))
        done
        
        log "Application restart failed - not responding to health checks"
        send_alert "CRITICAL" "Application restart failed - still not responding"
        return 1
    else
        log "Failed to start application containers"
        send_alert "CRITICAL" "Failed to start application containers"
        return 1
    fi
}

# Collect diagnostics
collect_diagnostics() {
    log "Collecting diagnostic information..."
    
    local diag_dir="/tmp/sms-diagnostics-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$diag_dir"
    
    # Docker status
    docker ps -a > "$diag_dir/docker-ps.txt" 2>&1
    docker stats --no-stream > "$diag_dir/docker-stats.txt" 2>&1
    
    # Container logs
    docker logs sms-api > "$diag_dir/app-logs.txt" 2>&1 || true
    docker logs sms-prometheus > "$diag_dir/prometheus-logs.txt" 2>&1 || true
    docker logs sms-grafana > "$diag_dir/grafana-logs.txt" 2>&1 || true
    
    # System resources
    free -h > "$diag_dir/memory.txt" 2>&1
    df -h > "$diag_dir/disk.txt" 2>&1
    top -bn1 | head -20 > "$diag_dir/cpu.txt" 2>&1
    
    # Network
    netstat -tulpn > "$diag_dir/network.txt" 2>&1
    
    # Application health
    curl -s "http://localhost:5000/health" > "$diag_dir/health-check.json" 2>&1 || echo "Health check failed" > "$diag_dir/health-check.json"
    curl -s "http://localhost:5000/metrics" > "$diag_dir/metrics.txt" 2>&1 || echo "Metrics check failed" > "$diag_dir/metrics.txt"
    
    log "Diagnostics collected in $diag_dir"
    echo "$diag_dir"
}

# Main incident response handler
handle_incident() {
    local incident_type="${1:-unknown}"
    
    case "$incident_type" in
        "app_down")
            log "Handling application down incident"
            send_alert "CRITICAL" "Application is down - initiating recovery"
            
            # Collect diagnostics first
            diag_dir=$(collect_diagnostics)
            
            # Attempt restart
            if restart_application; then
                log "Application recovery successful"
            else
                log "Automatic recovery failed - manual intervention required"
                send_alert "CRITICAL" "Automatic recovery failed - manual intervention required. Diagnostics: $diag_dir"
            fi
            ;;
            
        "high_error_rate")
            log "Handling high error rate incident"
            send_alert "WARNING" "High error rate detected"
            
            # Collect diagnostics
            diag_dir=$(collect_diagnostics)
            
            # Check if restart is needed (error rate > 20%)
            error_rate=$(curl -s "http://localhost:9090/api/v1/query?query=rate(flask_http_request_exceptions_total[5m])" | jq -r '.data.result[0].value[1] // "0"')
            
            if (( $(echo "$error_rate > 0.2" | bc -l) )); then
                log "Error rate too high ($error_rate), attempting restart"
                restart_application
            fi
            ;;
            
        "resource_exhaustion")
            log "Handling resource exhaustion incident"
            send_alert "WARNING" "System resources are critically low"
            
            # Clean up old Docker images and containers
            docker system prune -f >/dev/null 2>&1 || true
            
            # Collect diagnostics
            collect_diagnostics
            
            log "Resource cleanup completed"
            ;;
            
        *)
            log "Unknown incident type: $incident_type"
            collect_diagnostics
            ;;
    esac
}

# Continuous monitoring loop
monitor() {
    log "Starting continuous monitoring..."
    
    while true; do
        if ! check_health; then
            handle_incident "app_down"
        fi
        
        sleep 60
    done
}

# Usage information
usage() {
    cat << EOF
SMS Application Incident Response Tool

Usage: $0 [COMMAND]

Commands:
    monitor                 Start continuous monitoring
    restart                 Restart the application
    diagnose                Collect diagnostic information
    handle <incident_type>  Handle specific incident type
    health                  Check application health

Incident types:
    app_down               Application is not responding
    high_error_rate        High error rate detected
    resource_exhaustion    System resources critically low

Environment Variables:
    ALERT_WEBHOOK_URL      Webhook URL for sending alerts (optional)

Examples:
    $0 monitor              # Start monitoring daemon
    $0 restart              # Force restart application
    $0 handle app_down      # Handle application down incident
    $0 diagnose             # Collect diagnostics
EOF
}

# Main script logic
case "${1:-}" in
    "monitor")
        monitor
        ;;
    "restart")
        restart_application
        ;;
    "diagnose")
        collect_diagnostics
        ;;
    "handle")
        if [[ -n "${2:-}" ]]; then
            handle_incident "$2"
        else
            echo "Error: Incident type required"
            usage
            exit 1
        fi
        ;;
    "health")
        if check_health; then
            echo "✅ Application is healthy"
            exit 0
        else
            echo "❌ Application is not responding"
            exit 1
        fi
        ;;
    *)
        usage
        exit 1
        ;;
esac
