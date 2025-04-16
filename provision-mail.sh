#!/bin/bash

# === Configuration ===
TEMPLATE_DIR="./template"
TARGET_DIR="./tenants"
NETWORK_NAME="mail_net"
INFRA_POSTGRES_HOST="10.1.0.2"

# === Get user input ===
read -p "Enter domain (e.g., dreamcoderz.com): " DOMAIN

# Derive DB name by replacing dots with underscores
DB_NAME=$(echo "$DOMAIN" | tr '.' '_')
TENANT_DIR="${TARGET_DIR}/${DOMAIN}"

# Check if tenant already exists
if [ -d "$TENANT_DIR" ]; then
  echo "❌ Tenant already exists: $TENANT_DIR"
  exit 1
fi

# Copy template to tenant directory
mkdir -p "$TENANT_DIR"
cp -r "$TEMPLATE_DIR/"* "$TENANT_DIR/"

# Replace placeholders
sed -i "s|\${DOMAIN}|${DOMAIN}|g" "$TENANT_DIR/docker-compose.yml"
sed -i "s|\${DB_NAME}|${DB_NAME}|g" "$TENANT_DIR/docker-compose.yml"
sed -i "s|\${DOMAIN}|${DOMAIN}|g" "$TENANT_DIR/config/config.toml"

# Ensure Docker network exists
docker network inspect "$NETWORK_NAME" >/dev/null 2>&1 || docker network create "$NETWORK_NAME"

# Launch the tenant container
cd "$TENANT_DIR"
docker compose up -d

echo "✅ Tenant for $DOMAIN deployed successfully."
