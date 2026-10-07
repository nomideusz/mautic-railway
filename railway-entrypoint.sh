#!/bin/bash
# Mautic's web server, cron and queue workers in one container. Upstream runs
# them as three containers sharing the config and media volumes; Railway can't
# mount one volume into several services, so they share a container instead.
# Without cron no segment rebuilds and no campaign fires; without the workers
# queued emails are never sent. supervisord (PID 1) runs and restarts all five.
set -euo pipefail

# Railway's image unpacking can restore files that a later layer deleted:
# php:apache disables mpm_event that way, and Apache then refuses to start
# ("More than one MPM loaded"). Locally the image is fine.
rm -f /etc/apache2/mods-enabled/mpm_event.* /etc/apache2/mods-enabled/mpm_worker.*

# Railway mounts the volume root-owned, with lost+found at the top. -n: seed
# what's missing, never overwrite.
cp -an /opt/volume-seed/. /data/

# With an https site_url every Mautic route requires https, and Railway's proxy
# talks plain http to the container: trust it (only it can connect directly) so
# X-Forwarded-Proto counts, or each request redirects to itself. Mautic's trust
# middleware reads only local.php and this file, and Settings can't overwrite it.
cat > /data/config/parameters_local.php <<'PHP'
<?php
// Written by railway-entrypoint.sh on every boot.
$parameters = ['trusted_proxies' => ['REMOTE_ADDR']];
PHP

until mysqladmin ping --silent -h"$MAUTIC_DB_HOST" -P"${MAUTIC_DB_PORT:-3306}" -u"$MAUTIC_DB_USER" -p"$MAUTIC_DB_PASSWORD" 2>/dev/null; do
  echo "waiting for MySQL"; sleep 2
done

# First boot: unattended install with the admin from the template variables.
# After that local.php has site_url, and the web role runs migrations instead.
if ! php -r '@include "/data/config/local.php"; exit(empty($parameters["site_url"]) ? 1 : 0);'; then
  setpriv --reuid=www-data --regid=www-data --init-groups php /var/www/html/bin/console mautic:install --force \
    --db_host="$MAUTIC_DB_HOST" --db_port="${MAUTIC_DB_PORT:-3306}" --db_name="$MAUTIC_DB_DATABASE" \
    --db_user="$MAUTIC_DB_USER" --db_password="$MAUTIC_DB_PASSWORD" \
    --admin_username=admin --admin_firstname=Mautic --admin_lastname=Admin \
    --admin_email="$MAUTIC_ADMIN_EMAIL" --admin_password="$MAUTIC_ADMIN_PASSWORD" "$MAUTIC_URL"
fi

# The image's compiled container predates site_url, so it allows plain http
# and sends a non-Secure session cookie until the first Settings save rebuilds
# it. Rebuild now, so the healthcheck tests what actually runs.
setpriv --reuid=www-data --regid=www-data --init-groups php /var/www/html/bin/console cache:clear

exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
