#!/usr/bin/env bash
# Helper script to prepare an EC2 instance to run the Spring Boot jar as a systemd service.
# Usage (run on the EC2 instance as sudo or a user with sudo privileges):
#   sudo bash setup-systemd.sh [service-name] [deploy-dir] [run-user]
# Example:
#   sudo bash setup-systemd.sh helloworld /opt/helloworld ubuntu

set -euo pipefail

SERVICE_NAME=${1:-helloworld}
DEPLOY_DIR=${2:-/opt/helloworld}
RUN_USER=${3:-ubuntu}

echo "Service: $SERVICE_NAME"
echo "Deploy dir: $DEPLOY_DIR"
echo "Run user: $RUN_USER"

if [ "$EUID" -ne 0 ]; then
  echo "This script should be run with sudo/root to install packages and create systemd unit."
  exit 1
fi

# Detect package manager and install Java 17
if [ -f /etc/os-release ]; then
  . /etc/os-release
fi

install_java() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y openjdk-17-jdk
  elif command -v yum >/dev/null 2>&1; then
    yum install -y java-17-amazon-corretto-devel || yum install -y java-17-openjdk-devel
  else
    echo "Unsupported OS. Please install Java 17 manually."
    exit 1
  fi
}

install_java

# Create deploy directory and set ownership
mkdir -p "$DEPLOY_DIR"
chown -R "$RUN_USER":"$RUN_USER" "$DEPLOY_DIR"
chmod 755 "$DEPLOY_DIR"

[ -e /etc/default ] || mkdir -p /etc/default
# Ensure an environment file exists (can be populated from CI via secrets)
ENV_FILE=/etc/default/${SERVICE_NAME}
if [ ! -f "$ENV_FILE" ]; then
  touch "$ENV_FILE"
  chmod 640 "$ENV_FILE"
  chown root:root "$ENV_FILE"
fi

SERVICE_FILE=/etc/systemd/system/${SERVICE_NAME}.service
cat > "$SERVICE_FILE" <<'EOF'
[Unit]
Description=${SERVICE_NAME} Spring Boot service
After=network.target

[Service]
User=${RUN_USER}
WorkingDirectory=${DEPLOY_DIR}
EnvironmentFile=/etc/default/${SERVICE_NAME}
ExecStart=/usr/bin/java ${JAVA_OPTS-} -jar ${DEPLOY_DIR}/app.jar
SuccessExitStatus=143
Restart=on-failure
RestartSec=10
# Add environment variables here if needed, example:
# For application-specific env vars, populate /etc/default/${SERVICE_NAME} (KEY=value lines).

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$SERVICE_FILE"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"

echo "Systemd unit created at $SERVICE_FILE. Place your jar as $DEPLOY_DIR/app.jar and start with:"
echo "  sudo systemctl start $SERVICE_NAME"
echo "Check status with: sudo systemctl status $SERVICE_NAME"


