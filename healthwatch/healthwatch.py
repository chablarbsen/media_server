#!/usr/bin/env python3
"""
HealthWatch - Media Server Monitoring Service
Monitors Docker containers and sends email alerts when services go offline
"""

import os
import json
import time
import logging
import threading
from datetime import datetime, timedelta
from typing import Dict, List, Optional

import docker
import requests
import schedule
from flask import Flask, render_template, jsonify

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# Configuration from environment variables
CHECK_INTERVAL_MINUTES = int(os.getenv('CHECK_INTERVAL_MINUTES', '15'))
MAILGUN_API_KEY = os.getenv('MAILGUN_API_KEY', '')
MAILGUN_DOMAIN = os.getenv('MAILGUN_DOMAIN', '')
ADMIN_EMAILS = os.getenv('ADMIN_EMAILS', '').split(',')
FROM_EMAIL = os.getenv('FROM_EMAIL', 'healthwatch@serenity.watch')
ALERT_COOLDOWN_MINUTES = int(os.getenv('ALERT_COOLDOWN_MINUTES', '60'))
STATE_FILE = '/data/healthwatch_state.json'

# Critical services to monitor
CRITICAL_SERVICES = {
    'gluetun': {'type': 'container', 'description': 'VPN Gateway'},
    'plex': {'type': 'container', 'description': 'Media Server', 'http_check': 'http://plex:32400/web/index.html'},
    'sonarr': {'type': 'container', 'description': 'TV Show Manager', 'http_check': 'http://sonarr:8989/sonarr/ping'},
    'radarr': {'type': 'container', 'description': 'Movie Manager', 'http_check': 'http://radarr:7878/radarr/ping'},
    'prowlarr': {'type': 'container', 'description': 'Indexer Manager', 'http_check': 'http://prowlarr:9696/prowlarr/ping'},
    'bazarr': {'type': 'container', 'description': 'Subtitle Manager', 'http_check': 'http://bazarr:6767/bazarr/ping'},
    'traefik': {'type': 'container', 'description': 'Reverse Proxy'},
    'cloudflared': {'type': 'container', 'description': 'Cloudflare Tunnel'},
    'deluge': {'type': 'container', 'description': 'Torrent Client'},
    'sabnzbd': {'type': 'container', 'description': 'Usenet Client'},
}

# Flask app for web dashboard
app = Flask(__name__)

# Global state
service_status = {}
last_alert_time = {}
alert_history = []


class HealthMonitor:
    def __init__(self):
        self.docker_client = docker.from_env()
        self.load_state()

    def load_state(self):
        """Load previous state from file"""
        global last_alert_time, alert_history
        try:
            if os.path.exists(STATE_FILE):
                with open(STATE_FILE, 'r') as f:
                    state = json.load(f)
                    last_alert_time = {k: datetime.fromisoformat(v) for k, v in state.get('last_alert_time', {}).items()}
                    alert_history = state.get('alert_history', [])
                    logger.info("Loaded previous state from disk")
        except Exception as e:
            logger.error(f"Error loading state: {e}")

    def save_state(self):
        """Save current state to file"""
        try:
            state = {
                'last_alert_time': {k: v.isoformat() for k, v in last_alert_time.items()},
                'alert_history': alert_history[-100:]  # Keep last 100 alerts
            }
            with open(STATE_FILE, 'w') as f:
                json.dump(state, f, indent=2)
        except Exception as e:
            logger.error(f"Error saving state: {e}")

    def check_container_health(self, container_name: str) -> Dict:
        """Check if a container is running and healthy"""
        try:
            container = self.docker_client.containers.get(container_name)
            state = container.attrs['State']

            status = {
                'name': container_name,
                'running': state['Running'],
                'status': state['Status'],
                'health': state.get('Health', {}).get('Status', 'N/A'),
                'started_at': state.get('StartedAt', 'Unknown'),
                'healthy': state['Running']
            }

            # If container has healthcheck, use it
            if 'Health' in state:
                status['healthy'] = state['Health']['Status'] == 'healthy'

            return status

        except docker.errors.NotFound:
            return {
                'name': container_name,
                'running': False,
                'status': 'not_found',
                'health': 'N/A',
                'healthy': False,
                'error': 'Container not found'
            }
        except Exception as e:
            logger.error(f"Error checking {container_name}: {e}")
            return {
                'name': container_name,
                'running': False,
                'status': 'error',
                'health': 'N/A',
                'healthy': False,
                'error': str(e)
            }

    def check_http_endpoint(self, url: str, timeout: int = 5) -> bool:
        """Check if an HTTP endpoint is responding"""
        try:
            response = requests.get(url, timeout=timeout)
            return response.status_code == 200
        except Exception as e:
            logger.debug(f"HTTP check failed for {url}: {e}")
            return False

    def check_all_services(self) -> Dict[str, Dict]:
        """Check all monitored services"""
        global service_status

        results = {}
        for service_name, config in CRITICAL_SERVICES.items():
            # Check container health
            status = self.check_container_health(service_name)

            # If container is running and has HTTP check, verify endpoint
            if status['running'] and 'http_check' in config:
                http_healthy = self.check_http_endpoint(config['http_check'])
                status['http_healthy'] = http_healthy
                status['healthy'] = status['healthy'] and http_healthy

            status['description'] = config['description']
            results[service_name] = status

        service_status = results
        return results

    def should_send_alert(self, service_name: str) -> bool:
        """Check if we should send an alert (respects cooldown)"""
        if service_name not in last_alert_time:
            return True

        time_since_last_alert = datetime.now() - last_alert_time[service_name]
        return time_since_last_alert > timedelta(minutes=ALERT_COOLDOWN_MINUTES)

    def send_email_alert(self, service_name: str, status: Dict):
        """Send email alert for service failure using Mailgun"""
        if not MAILGUN_API_KEY or not MAILGUN_DOMAIN:
            logger.warning("Mailgun API key or domain not configured, skipping email alert")
            return

        if not ADMIN_EMAILS or ADMIN_EMAILS == ['']:
            logger.warning("Admin emails not configured, skipping email alert")
            return

        if not self.should_send_alert(service_name):
            logger.info(f"Alert cooldown active for {service_name}, skipping email")
            return

        try:
            subject = f"⚠️ ALERT: {service_name} is DOWN"

            error_details = status.get('error', 'Service is not responding')
            if not status['running']:
                error_details = "Container is not running"
            elif status.get('http_healthy') is False:
                error_details = "Container running but HTTP endpoint not responding"

            html_content = f"""
            <html>
            <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <div style="background-color: #ff4444; color: white; padding: 20px; border-radius: 5px;">
                    <h2>🚨 Service Alert</h2>
                </div>
                <div style="padding: 20px; background-color: #f5f5f5; margin-top: 10px; border-radius: 5px;">
                    <h3>{service_name} ({status['description']}) is DOWN</h3>
                    <p><strong>Time:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
                    <p><strong>Status:</strong> {status['status']}</p>
                    <p><strong>Health:</strong> {status['health']}</p>
                    <p><strong>Error:</strong> {error_details}</p>
                </div>
                <div style="padding: 20px; margin-top: 10px;">
                    <p><strong>Recommended Actions:</strong></p>
                    <ul>
                        <li>Check service logs: <code>docker logs {service_name}</code></li>
                        <li>Restart service: <code>docker restart {service_name}</code></li>
                        <li>View all services: <code>docker ps -a</code></li>
                    </ul>
                    <p style="color: #666; font-size: 12px; margin-top: 30px;">
                        This alert was sent by HealthWatch monitoring service.<br>
                        Alerts are throttled to once per {ALERT_COOLDOWN_MINUTES} minutes per service.
                    </p>
                </div>
            </body>
            </html>
            """

            # Send email using Mailgun API
            response = requests.post(
                f"https://api.mailgun.net/v3/{MAILGUN_DOMAIN}/messages",
                auth=("api", MAILGUN_API_KEY),
                data={
                    "from": FROM_EMAIL,
                    "to": ADMIN_EMAILS,
                    "subject": subject,
                    "html": html_content
                }
            )

            if response.status_code == 200:
                logger.info(f"Alert email sent for {service_name} to {len(ADMIN_EMAILS)} admins")
                last_alert_time[service_name] = datetime.now()

                # Add to alert history
                alert_history.append({
                    'service': service_name,
                    'timestamp': datetime.now().isoformat(),
                    'status': status['status'],
                    'error': error_details
                })

                self.save_state()
            else:
                logger.error(f"Mailgun API error: {response.status_code} - {response.text}")

        except Exception as e:
            logger.error(f"Error sending email alert: {e}")

    def monitor_services(self):
        """Main monitoring function"""
        logger.info("Running service health checks...")

        results = self.check_all_services()

        # Check for failures and send alerts
        failed_services = []
        for service_name, status in results.items():
            if not status['healthy']:
                logger.warning(f"Service {service_name} is unhealthy: {status}")
                failed_services.append(service_name)
                self.send_email_alert(service_name, status)

        if failed_services:
            logger.warning(f"Unhealthy services: {', '.join(failed_services)}")
        else:
            logger.info("All services healthy ✓")

        return results


# Flask routes for web dashboard
@app.route('/')
def dashboard():
    """Main dashboard page"""
    return render_template('dashboard.html')

@app.route('/api/status')
def api_status():
    """API endpoint for current status"""
    healthy_count = sum(1 for s in service_status.values() if s.get('healthy', False))
    total_count = len(service_status)

    return jsonify({
        'timestamp': datetime.now().isoformat(),
        'services': service_status,
        'summary': {
            'healthy': healthy_count,
            'total': total_count,
            'unhealthy': total_count - healthy_count
        },
        'last_check': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    })

@app.route('/api/history')
def api_history():
    """API endpoint for alert history"""
    return jsonify({
        'alerts': alert_history[-50:],  # Last 50 alerts
        'total': len(alert_history)
    })


def run_scheduler():
    """Run the monitoring scheduler in background thread"""
    monitor = HealthMonitor()

    # Run initial check
    monitor.monitor_services()

    # Schedule periodic checks
    schedule.every(CHECK_INTERVAL_MINUTES).minutes.do(monitor.monitor_services)

    logger.info(f"Scheduler started - checking every {CHECK_INTERVAL_MINUTES} minutes")

    while True:
        schedule.run_pending()
        time.sleep(60)


def run_flask():
    """Run Flask web dashboard"""
    app.run(host='0.0.0.0', port=8888, debug=False)


def wait_for_services_ready():
    """
    Wait for critical services to be ready before starting monitoring.
    This prevents false positive alerts during cold boots or after power outages.
    Waits up to 15 minutes with 2-minute initial timeout for cold starts.
    """
    logger.info("=" * 60)
    logger.info("Waiting for services to initialize (cold boot protection)...")
    logger.info("=" * 60)

    max_wait_minutes = 15  # Maximum wait time
    cold_boot_timeout_minutes = 2  # Minimum wait before starting checks
    check_interval_seconds = 15
    start_time = datetime.now()

    # Always wait at least 2 minutes on startup (cold boot protection)
    logger.info(f"Cold boot protection: waiting {cold_boot_timeout_minutes} minutes for all services to start...")
    time.sleep(cold_boot_timeout_minutes * 60)

    while True:
        elapsed = (datetime.now() - start_time).total_seconds() / 60

        if elapsed > max_wait_minutes:
            logger.warning(f"Timeout: Waited {max_wait_minutes} minutes. Starting monitoring anyway.")
            break

        try:
            # Check if Docker is accessible
            client = docker.from_env()

            # Count how many monitored services are running and healthy
            running_count = 0
            for service_name in CRITICAL_SERVICES.keys():
                try:
                    container = client.containers.get(service_name)
                    state = container.attrs['State']

                    # Consider service ready if:
                    # 1. It's running AND
                    # 2. Either has no healthcheck OR healthcheck is healthy
                    if state['Running']:
                        health_status = state.get('Health', {}).get('Status', 'none')
                        if health_status in ['healthy', 'none']:  # 'none' means no healthcheck
                            running_count += 1
                except:
                    pass

            total_services = len(CRITICAL_SERVICES)
            logger.info(f"Services ready: {running_count}/{total_services} ({int(elapsed*60)}s elapsed)")

            # Wait until at least 80% of services are running
            if running_count >= total_services * 0.8:
                logger.info(f"✓ {running_count}/{total_services} services running - ready to monitor")
                # Additional grace period for services to fully initialize
                logger.info("Waiting 30s grace period for services to fully initialize...")
                time.sleep(30)
                break

        except Exception as e:
            logger.warning(f"Error checking services: {e}")

        time.sleep(check_interval_seconds)


if __name__ == '__main__':
    logger.info("=" * 60)
    logger.info("HealthWatch Media Server Monitoring Service")
    logger.info("=" * 60)
    logger.info(f"Check Interval: {CHECK_INTERVAL_MINUTES} minutes")
    logger.info(f"Alert Cooldown: {ALERT_COOLDOWN_MINUTES} minutes")
    logger.info(f"Monitoring {len(CRITICAL_SERVICES)} services")
    logger.info(f"Admin Emails: {len([e for e in ADMIN_EMAILS if e])} configured")
    logger.info("=" * 60)

    # Wait for services to be ready (prevents false alerts on cold boot)
    wait_for_services_ready()

    # Start scheduler in background thread
    scheduler_thread = threading.Thread(target=run_scheduler, daemon=True)
    scheduler_thread.start()

    # Run Flask app in main thread
    run_flask()
