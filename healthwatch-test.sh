#!/bin/bash
# HealthWatch Testing Script
# Quick commands for testing the monitoring system

set -e

echo "🏥 HealthWatch Testing Menu"
echo "================================"
echo ""
echo "1. Check if HealthWatch is running"
echo "2. View HealthWatch logs (last 50 lines)"
echo "3. View HealthWatch logs (live tail)"
echo "4. Test alert by stopping/starting bazarr"
echo "5. Check current service status (API)"
echo "6. Force immediate health check (restart container)"
echo "7. View alert history"
echo "8. Check environment variables"
echo "9. Reset alert cooldowns"
echo ""

read -p "Select option (1-9): " option

case $option in
  1)
    echo ""
    echo "Checking HealthWatch status..."
    if docker ps | grep -q healthwatch; then
      echo "✅ HealthWatch is RUNNING"
      docker ps | grep healthwatch
    else
      echo "❌ HealthWatch is NOT running"
      echo ""
      echo "Start it with: docker-compose up -d healthwatch"
    fi
    ;;

  2)
    echo ""
    echo "HealthWatch logs (last 50 lines):"
    echo "================================"
    docker logs healthwatch --tail 50
    ;;

  3)
    echo ""
    echo "HealthWatch logs (live - press Ctrl+C to exit):"
    echo "================================"
    docker logs healthwatch --tail 20 -f
    ;;

  4)
    echo ""
    echo "Testing alert system with bazarr..."
    echo "================================"
    echo "Step 1: Stopping bazarr..."
    docker stop bazarr
    echo "✅ Bazarr stopped"
    echo ""
    echo "Step 2: Triggering immediate health check..."
    docker restart healthwatch
    echo "✅ HealthWatch restarted (this triggers immediate check)"
    echo ""
    echo "Step 3: Waiting 10 seconds for check to complete..."
    sleep 10
    echo ""
    echo "Step 4: Checking logs for alert..."
    docker logs healthwatch --tail 30 | grep -i -A5 -B5 "bazarr\|alert\|email"
    echo ""
    echo "Step 5: Restoring bazarr..."
    docker start bazarr
    echo "✅ Bazarr restarted"
    echo ""
    echo "📧 Check your email for the alert!"
    echo "Dashboard: http://serenity.watch/healthwatch"
    ;;

  5)
    echo ""
    echo "Current service status:"
    echo "================================"
    docker exec healthwatch curl -s http://localhost:8888/api/status | python3 -m json.tool
    ;;

  6)
    echo ""
    echo "Forcing immediate health check..."
    docker restart healthwatch
    echo "✅ HealthWatch restarted - health check will run on startup"
    echo ""
    echo "View logs with: docker logs healthwatch -f"
    ;;

  7)
    echo ""
    echo "Alert history:"
    echo "================================"
    if [ -f "./healthwatch/data/healthwatch_state.json" ]; then
      cat ./healthwatch/data/healthwatch_state.json | python3 -m json.tool
    else
      echo "No alert history file found yet"
    fi
    ;;

  8)
    echo ""
    echo "HealthWatch environment variables:"
    echo "================================"
    echo "CHECK_INTERVAL_MINUTES:"
    docker exec healthwatch printenv CHECK_INTERVAL_MINUTES
    echo ""
    echo "ALERT_COOLDOWN_MINUTES:"
    docker exec healthwatch printenv ALERT_COOLDOWN_MINUTES
    echo ""
    echo "SENDGRID_API_KEY (masked):"
    docker exec healthwatch printenv SENDGRID_API_KEY | sed 's/\(SG\.[^.]*\).*/\1...REDACTED/'
    echo ""
    echo "ADMIN_EMAILS:"
    docker exec healthwatch printenv ADMIN_EMAILS
    echo ""
    echo "FROM_EMAIL:"
    docker exec healthwatch printenv FROM_EMAIL
    ;;

  9)
    echo ""
    echo "Resetting alert cooldowns..."
    if [ -f "./healthwatch/data/healthwatch_state.json" ]; then
      mv ./healthwatch/data/healthwatch_state.json ./healthwatch/data/healthwatch_state.json.backup
      echo "✅ State file backed up and removed"
    else
      echo "ℹ️  No state file to reset"
    fi
    docker restart healthwatch
    echo "✅ HealthWatch restarted - cooldowns reset"
    ;;

  *)
    echo "Invalid option"
    exit 1
    ;;
esac

echo ""
echo "Done!"
