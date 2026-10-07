# Deploy and Host Mautic on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/mautic-production?utm_medium=integration&utm_source=button&utm_campaign=mautic-production)

[Mautic](https://mautic.org/) is the open-source marketing automation platform: contacts and segments, newsletters and email campaigns, forms and landing pages, lead scoring, and multi-step campaigns triggered by what your contacts do. It is an alternative to HubSpot Marketing Hub, ActiveCampaign and Mailchimp, with no per-contact pricing. This template runs Mautic 7.2.1 together with the cron jobs and queue workers that make campaigns actually run.

## About Hosting Mautic

The stack is two services: Mautic and MySQL.

- **Mautic** runs the web app, cron and the queue workers in one container. **Cron and the workers are what make Mautic do anything on its own.** Every 15 minutes segments rebuild, campaigns pick up new contacts and fire their due events, and scheduled segment emails go out. Background imports and exports also run on cron. The workers send the queued emails and record opens and page visits. The most-deployed Mautic templates on Railway run the web app only, so you can build a campaign there but it never fires. Upstream's Docker setup runs web, cron and worker as three containers that share config and media volumes. Railway volumes can't be shared between services, so here they run under one supervisor, which restarts any process that stops.
- **Settings survive redeploys.** Mautic keeps everything you save under Settings, including your email credentials, in `config/local.php`. That file also holds the secret key that encrypts integration credentials. Here it lives on the Mautic volume, along with your uploaded images and files. Without a volume, both are lost on every redeploy.
- **Sends without SMTP.** Railway blocks outbound SMTP below the Pro plan. The image adds the HTTPS API transports for Amazon SES, Brevo, Mailgun, Mailjet, Postmark, Resend and SendGrid, so Mautic sends on any plan.
- **Installed for you.** The admin account is created on the first boot from the email you enter at deploy time. There is no install wizard, so nobody else can claim a freshly deployed instance.
- **MySQL 8.4 LTS**, the database upstream's Docker setup uses. `performance_schema` is turned off, which saves about 300 MB of idle memory.

## Common Use Cases

- Newsletters and segment emails to your own list, without per-contact pricing
- Drip and nurture campaigns triggered by form submissions, page visits and email opens
- Lead scoring and website visitor tracking, so sales gets the warm leads

## Dependencies for Mautic Hosting

- MySQL 8.4 (included, private network only)
- An email sending service: an API key from Amazon SES, Brevo, Mailgun, Mailjet, Postmark, Resend or SendGrid, or SMTP credentials on the Pro plan

### Deployment Dependencies

- [Mautic documentation](https://docs.mautic.org/en/latest/)
- [Mautic cron jobs](https://docs.mautic.org/en/latest/configuration/cron_jobs.html)
- [Symfony Mailer third-party transports](https://symfony.com/doc/current/mailer.html#using-a-3rd-party-transport) (DSN formats)
- [Mautic Docker image](https://github.com/mautic/docker-mautic)
- [Template source on GitHub](https://github.com/nomideusz/mautic-railway)

### Implementation Details

**Sign in** at the Mautic service's Railway domain with username `admin` (or your email). The password is `MAUTIC_ADMIN_PASSWORD` in the Mautic service's Variables tab. The first boot installs Mautic and takes about a minute.

1. **Connect an email service.** Open Settings (the gear icon) → Configuration → Email Settings. Set your sender name and address, then fill in the DSN fields for your provider. For example, SendGrid is Scheme `sendgrid+api`, Host `default`, User = your API key. Then click **Send test email**.

   | Provider | DSN |
   | --- | --- |
   | Amazon SES | `ses+api://ACCESS_KEY:SECRET_KEY@default?region=eu-west-1` |
   | Brevo | `brevo+api://API_KEY@default` |
   | Mailgun | `mailgun+api://API_KEY:DOMAIN@default?region=us` |
   | Mailjet | `mailjet+api://ACCESS_KEY:SECRET_KEY@default` |
   | Postmark | `postmark+api://SERVER_TOKEN@default` |
   | Resend | `resend+api://API_KEY@default` |
   | SendGrid | `sendgrid+api://API_KEY@default` |

2. **Track your website.** Settings → Configuration → Tracking Settings has the script to paste into your site.
3. **Build forms, segments and campaigns.** Campaigns run on the cron schedule below. There's no need to trigger them by hand.

**Cron schedule:**

| Job | Schedule |
| --- | --- |
| Segments rebuild | :00, :15, :30, :45 |
| Campaigns add new contacts | :05, :20, :35, :50 |
| Campaign events fire | :10, :25, :40, :55 |
| Scheduled segment emails | :02, :17, :32, :47 |
| Background imports | every 5 minutes |
| Scheduled exports | :07, :22, :37, :52 |
| Scheduled reports | hourly at :12 |

A scheduled segment email goes to the contacts who were in the segment at its publish time.

**Sending speed.** One worker consumes each queue. For large lists, set `DOCKER_MAUTIC_WORKERS_CONSUME_EMAIL` to `2` or more on the Mautic service.

**Memory.** Expect about 400 MB at idle: roughly 200 MB for Mautic (Apache, cron and three workers) and 200 MB for MySQL. Hobby or above is recommended once you send to real lists.

**Custom domains.** Add the domain under the Mautic service's Settings → Networking, then change the Site URL under Mautic's Settings → Configuration. `MAUTIC_URL` is only read at install.

**Upgrades.** Database migrations run automatically when the container starts. Back up before redeploying onto a newer Mautic version.

**Backups.** Turn on Railway's volume backups for MySQL (contacts, campaigns, stats) and for the Mautic volume (`local.php` with the secret key, plus your uploads).

## Why Deploy Mautic on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Mautic on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
