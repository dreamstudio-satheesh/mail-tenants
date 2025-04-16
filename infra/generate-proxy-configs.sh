#!/bin/bash

TENANT_FILE="./tenants.csv"
HAPROXY_CFG="./haproxy.cfg"
CADDYFILE="./Caddyfile"

echo "[+] Generating haproxy.cfg..."

cat > "$HAPROXY_CFG" <<EOF
defaults
  log global
  mode tcp
  timeout connect 5s
  timeout client 30s
  timeout server 30s

frontend smtp_front
  bind *:25
  mode tcp
EOF

# Add backend rules (SMTP + IMAPS)
while IFS=',' read -r domain ip; do
  [[ "$domain" =~ ^#.*$ || -z "$domain" ]] && continue
  id=$(echo "$domain" | tr '.' '_')
  echo "  use_backend smtp_$id if { req.ssl_sni -i $domain }" >> "$HAPROXY_CFG"
done < "$TENANT_FILE"

echo >> "$HAPROXY_CFG"
echo "frontend imaps_front" >> "$HAPROXY_CFG"
echo "  bind *:993" >> "$HAPROXY_CFG"
echo "  mode tcp" >> "$HAPROXY_CFG"

while IFS=',' read -r domain ip; do
  [[ "$domain" =~ ^#.*$ || -z "$domain" ]] && continue
  id=$(echo "$domain" | tr '.' '_')
  echo "  use_backend imaps_$id if { req.ssl_sni -i $domain }" >> "$HAPROXY_CFG"
done < "$TENANT_FILE"

while IFS=',' read -r domain ip; do
  [[ "$domain" =~ ^#.*$ || -z "$domain" ]] && continue
  id=$(echo "$domain" | tr '.' '_')

  cat >> "$HAPROXY_CFG" <<EOF

backend smtp_$id
  mode tcp
  server $id $ip:25

backend imaps_$id
  mode tcp
  server $id $ip:993
EOF

done < "$TENANT_FILE"

echo "[✓] haproxy.cfg generated"

# -------------------------
echo "[+] Generating Caddyfile..."

cat > "$CADDYFILE" <<EOF
{
  email your-email@example.com
  acme_ca https://acme-v02.api.letsencrypt.org/directory
}
EOF

while IFS=',' read -r domain ip; do
  [[ "$domain" =~ ^#.*$ || -z "$domain" ]] && continue
  cat >> "$CADDYFILE" <<EOF

$domain {
  reverse_proxy $ip:8080
}
EOF
done < "$TENANT_FILE"

echo "[✓] Caddyfile generated"

# -------------------------
echo "[+] Restarting proxy containers..."
docker restart mail-haproxy mail-caddy
echo "[✓] All done."
