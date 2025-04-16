#!/bin/bash

# === CONFIG ===
TARGET_DIR="./tenants"
PG_HOST="10.1.0.2"
PG_PORT="5432"
PG_USER="mailadmin"
NETWORK_NAME="mail_net"

read -s -p "Enter PostgreSQL password for $PG_USER: " PG_PASS
echo
read -p "Enter tenant domain to remove (e.g., dreamcoderz.com): " DOMAIN

DB_NAME=$(echo "$DOMAIN" | tr '.' '_' | tr '[:upper:]' '[:lower:]')
TENANT_DIR="${TARGET_DIR}/${DOMAIN}"
VOLUME_NAME="mail_queue_${DOMAIN}"
CONTAINER_NAME="mail-${DOMAIN}"

# === Confirm Deletion ===
read -p "❗ Confirm delete tenant '${DOMAIN}' (y/n)? " confirm
if [[ "$confirm" != "y" ]]; then
  echo "❌ Aborted."
  exit 1
fi

# === 1. Stop and Remove Container ===
if [ -d "$TENANT_DIR" ]; then
  echo "🛑 Stopping and removing mail container for '$DOMAIN'..."
  docker compose -f "$TENANT_DIR/docker-compose.yml" down
  rm -rf "$TENANT_DIR"
else
  echo "⚠️ Tenant directory not found. Skipping container removal."
fi

# === 2. Remove Volume ===
echo "🧹 Removing volume $VOLUME_NAME..."
docker volume rm "$VOLUME_NAME" 2>/dev/null || echo "⚠️ Volume may already be removed."

# === 3. Drop PostgreSQL Database (via Infra) ===
echo "🗃️ Dropping DB '$DB_NAME' from PostgreSQL on $PG_HOST..."
PGPASSWORD=$PG_PASS psql -h "$PG_HOST" -U "$PG_USER" -p "$PG_PORT" -d postgres -c "DROP DATABASE IF EXISTS \"${DB_NAME}\";"

echo "✅ Tenant '$DOMAIN' removed from mail server and DB dropped on infra."
