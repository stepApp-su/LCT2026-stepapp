#!/usr/bin/env bash
set -euo pipefail
test "$(id -u)" = 0
public_key="${1:?Pass the deploy public key}"
[[ "$public_key" == ssh-ed25519\ * ]]
site=/etc/nginx/sites-available/lct2026.stepapp.su
if test -e "$site"; then
  echo 'Site already exists; inspect it before changing the configuration.' >&2
  exit 1
fi
if ! id finni-deploy >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash finni-deploy
fi
install -d -m 700 -o finni-deploy -g finni-deploy /home/finni-deploy/.ssh
touch /home/finni-deploy/.ssh/authorized_keys
if ! grep -qF "$public_key" /home/finni-deploy/.ssh/authorized_keys; then
  printf 'restrict %s\n' "$public_key" >> /home/finni-deploy/.ssh/authorized_keys
fi
chown finni-deploy:finni-deploy /home/finni-deploy/.ssh/authorized_keys
chmod 600 /home/finni-deploy/.ssh/authorized_keys
install -d -m 755 -o finni-deploy -g finni-deploy /srv/finni /srv/finni/releases
install -d -m 755 /var/www/letsencrypt
install -m 644 "$(dirname "$0")/nginx.conf" "$site"
ln -s "$site" /etc/nginx/sites-enabled/lct2026.stepapp.su
nginx -t
systemctl reload nginx
certbot --nginx --non-interactive --agree-tos --register-unsafely-without-email --redirect -d lct2026.stepapp.su
nginx -t
systemctl reload nginx
