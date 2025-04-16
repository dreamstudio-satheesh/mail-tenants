#!/bin/bash

# === CONFIG ===
TEMPLATE_DIR="./template"
TARGET_DIR="./tenants"
NETWORK_NAME="mail_net"
PG_HOST="10.1.0.2"
PG_PORT="5432"
PG_USER="mailadmin"
read -s -p "Enter PostgreSQL password for $PG_USER: " PG_PASS
echo

# === INPUT ===
read -p "Enter domain (e.g., dreamcoderz.com): " DOMAIN
DB_NAME=$(echo "$DOMAIN" | tr '.' '_' | tr '[:upper:]' '[:lower:]')
TENANT_DIR="${TARGET_DIR}/${DOMAIN}"

# === CREATE TENANT FOLDER ===
if [ -d "$TENANT_DIR" ]; then
  echo "❌ Tenant already exists: $TENANT_DIR"
  exit 1
fi

mkdir -p "$TENANT_DIR"
cp -r "$TEMPLATE_DIR/"* "$TENANT_DIR/"

# === Replace placeholders ===
sed -i "s|\${DOMAIN}|${DOMAIN}|g" "$TENANT_DIR/docker-compose.yml"
sed -i "s|\${DB_NAME}|${DB_NAME}|g" "$TENANT_DIR/docker-compose.yml"
sed -i "s|\${DOMAIN}|${DOMAIN}|g" "$TENANT_DIR/config/config.toml"

# === PostgreSQL: Create DB ===
echo "Creating PostgreSQL DB '${DB_NAME}' on ${PG_HOST}..."
PGPASSWORD=$PG_PASS psql -h "$PG_HOST" -U "$PG_USER" -p "$PG_PORT" -d postgres -c "CREATE DATABASE \"${DB_NAME}\";" 2>/dev/null

if [ $? -ne 0 ]; then
  echo "⚠️ Warning: Database may already exist or there was an error."
else
  echo "✅ Database '${DB_NAME}' created successfully."
fi

# === Docker Network Check ===
docker network inspect "$NETWORK_NAME" >/dev/null 2>&1 || {
  echo "🧠 Creating Docker network: $NETWORK_NAME"
  docker network create "$NETWORK_NAME"
}

# === Launch Tenant Container ===
cd "$TENANT_DIR"
docker compose up -d

echo "✅ Tenant '$DOMAIN' is up and using database '$DB_NAME'."
