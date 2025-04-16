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

# === Generate random port and admin token ===
ADMIN_PORT=$(shuf -i 18000-18999 -n 1)
ADMIN_TOKEN=$(openssl rand -hex 12)

# === Replace placeholders ===
sed -i "s|\${DOMAIN}|${DOMAIN}|g" "$TENANT_DIR/docker-compose.yml"
sed -i "s|\${DB_NAME}|${DB_NAME}|g" "$TENANT_DIR/docker-compose.yml"
sed -i "s|\${ADMIN_PORT}|${ADMIN_PORT}|g" "$TENANT_DIR/docker-compose.yml"
sed -i "s|\${ADMIN_TOKEN}|${ADMIN_TOKEN}|g" "$TENANT_DIR/docker-compose.yml"
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

echo "✅ Tenant '$DOMAIN' is running"
echo "🔐 Admin UI: http://<mail1-ip>:${ADMIN_PORT}"
echo "🔑 Admin Token: ${ADMIN_TOKEN}"


# === CONFIG: Remote Infra ===
INFRA_IP="10.1.0.2"
CADDYFILE_REMOTE="/home/infra/caddy/Caddyfile"
MAIL1_IP="10.1.0.3"

# === Generate new reverse proxy block ===
CADDY_ENTRY=$(cat <<EOF

mail.${DOMAIN} {
  reverse_proxy /admin/* ${MAIL1_IP}:${ADMIN_PORT}
}
EOF
)

# === Inject into remote Caddyfile if not already added ===
ssh root@${INFRA_IP} "grep -q 'mail.${DOMAIN}' ${CADDYFILE_REMOTE} || echo \"$CADDY_ENTRY\" >> ${CADDYFILE_REMOTE}"

# === Reload Caddy remotely ===
ssh root@${INFRA_IP} "docker exec infra-caddy caddy reload --config /etc/caddy/Caddyfile"

echo "✅ Remote Caddy updated and reloaded for mail.${DOMAIN}"
