# Mautic's web server, cron and queue workers in one container (see
# railway-entrypoint.sh for why).
FROM mautic/mautic:7.2.1-20260923-apache

# HTTPS email API transports (SES, Brevo, Mailgun, Mailjet, Postmark, Resend,
# SendGrid). The stock image ships only SMTP, which Railway blocks below Pro.
RUN cd /var/www/html \
 && COMPOSER_ALLOW_SUPERUSER=1 composer require --no-interaction --no-progress --no-scripts \
      symfony/amazon-mailer symfony/brevo-mailer symfony/mailgun-mailer symfony/mailjet-mailer \
      symfony/postmark-mailer symfony/resend-mailer symfony/sendgrid-mailer \
 && php bin/console cache:clear \
 && chown -R www-data:www-data var

# One Railway volume at /data: config/ (local.php: secret key, everything saved
# under Settings) and the two upload dirs live there. Their stock contents
# (.htaccess files that stop uploads from executing) seed it on first boot.
RUN mkdir /opt/volume-seed \
 && mv /var/www/html/config /opt/volume-seed/config \
 && mv /var/www/html/docroot/media/files /opt/volume-seed/files \
 && mv /var/www/html/docroot/media/images /opt/volume-seed/images \
 && ln -s /data/config /var/www/html/config \
 && ln -s /data/files /var/www/html/docroot/media/files \
 && ln -s /data/images /var/www/html/docroot/media/images \
 && chown -h www-data:www-data /var/www/html/config /var/www/html/docroot/media/files /var/www/html/docroot/media/images

# One consumer per queue instead of two: each is a PHP process, and Railway bills RAM.
ENV DOCKER_MAUTIC_WORKERS_CONSUME_EMAIL=1 \
    DOCKER_MAUTIC_WORKERS_CONSUME_HIT=1 \
    DOCKER_MAUTIC_WORKERS_CONSUME_FAILED=1

# Once site_url is https, Mautic makes every route https-only. Real traffic
# carries X-Forwarded-Proto from Railway's proxy; the healthcheck doesn't, and a
# 301 fails it. Mark its requests secure so it still checks the login page.
RUN echo 'SetEnvIf User-Agent "^RailwayHealthCheck/" HTTPS=on' > /etc/apache2/conf-enabled/railway-healthcheck.conf

COPY mautic_cron /templates/mautic_cron
COPY supervisord-web-cron.conf /tmp/
RUN cat /tmp/supervisord-web-cron.conf >> /etc/supervisor/conf.d/supervisord.conf && rm /tmp/supervisord-web-cron.conf
COPY --chmod=755 railway-entrypoint.sh /railway-entrypoint.sh
ENTRYPOINT ["/railway-entrypoint.sh"]
