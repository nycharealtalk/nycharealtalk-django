#!/bin/bash
# First-time Let's Encrypt certificate setup.
# Run this once after DNS is pointed at the server but before `docker compose -f docker-compose.prod.yml up`.
#
# Usage: ./docker/init-letsencrypt.sh [--staging]
#   --staging  Use Let's Encrypt staging server (higher rate limits, for testing)

set -e

COMPOSE="docker compose -f docker-compose.prod.yml"
EMAIL="ebrelsford@stamen.com"
STAGING=0

# Read DOMAIN and TILES_DOMAIN from .env.prod
if [ -f .env.prod ]; then
  export $(grep -E '^(DOMAIN|TILES_DOMAIN)=' .env.prod | xargs)
fi
: "${DOMAIN:?Set DOMAIN in .env.prod}"
: "${TILES_DOMAIN:?Set TILES_DOMAIN in .env.prod}"

if [ "$1" = "--staging" ]; then
  STAGING=1
fi

STAGING_FLAG=""
if [ "$STAGING" = "1" ]; then
  STAGING_FLAG="--staging"
fi

# Create the certbot directories nginx expects
$COMPOSE run --rm certbot mkdir -p /var/www/certbot

# Create dummy self-signed certs so nginx can start before real certs exist
for D in "$DOMAIN" "$TILES_DOMAIN"; do
  echo "Creating dummy cert for $D..."
  $COMPOSE run --rm --entrypoint "" certbot sh -c "
    mkdir -p /etc/letsencrypt/live/$D &&
    openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
      -keyout /etc/letsencrypt/live/$D/privkey.pem \
      -out    /etc/letsencrypt/live/$D/fullchain.pem \
      -subj   '/CN=localhost'
  "
done

# Start nginx with dummy certs
echo "Starting nginx..."
$COMPOSE up -d nginx

# Get real certs
echo "Requesting cert for $DOMAIN..."
$COMPOSE run --rm --entrypoint "" certbot certbot certonly \
  --webroot -w /var/www/certbot \
  -d "$DOMAIN" -d "www.$DOMAIN" \
  --email "$EMAIL" --agree-tos --no-eff-email \
  $STAGING_FLAG

echo "Requesting cert for $TILES_DOMAIN..."
$COMPOSE run --rm --entrypoint "" certbot certbot certonly \
  --webroot -w /var/www/certbot \
  -d "$TILES_DOMAIN" \
  --email "$EMAIL" --agree-tos --no-eff-email \
  $STAGING_FLAG

# Reload nginx with real certs
echo "Reloading nginx..."
$COMPOSE exec nginx nginx -s reload

# Start remaining services
echo "Bringing up all services..."
$COMPOSE up -d

echo "Done. Certs will auto-renew via the certbot container."
