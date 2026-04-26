# virtualhost-scripts

Automatic Nginx virtual host management with Let's Encrypt SSL certificates, driven by filesystem events.

## How It Works

1. **`inotify.sh`** watches a directory (default: `/var/www`) for new or removed subdirectories using `inotifywait`.
2. When a directory is created/moved in, **`handle-nginx-virtualhost.sh`** automatically:
   - Validates DNS resolution for the domain
   - Creates an Nginx server block (HTTP → HTTPS redirect + SSL)
   - Enables the site and reloads Nginx
   - Obtains a Let's Encrypt certificate via Certbot
   - Activates SSL in the Nginx config and reloads again
3. When a directory is deleted/moved out, it removes the site config and cleans up the certificate.

## Requirements

- Linux with `inotify-tools` installed (`apt-get install inotify-tools`)
- Nginx installed and configured with `sites-available`/`sites-enabled`
- Certbot installed ([certbot.eff.org](https://certbot.eff.org/docs/install.html))
- `dig` (from `dnsutils` / `bind-utils`)
- Root privileges (manages Nginx configs and certificates)

## Usage

```bash
# Start watching /var/www with the default handler
sudo ./scripts/inotify.sh

# Watch a custom directory with the default handler
sudo ./scripts/inotify.sh /srv/websites

# Watch with a custom handler script
sudo ./scripts/inotify.sh /var/www /path/to/custom-handler.sh
```

### Creating a new site

```bash
# Simply create a directory named after the domain
mkdir /var/www/example.com
# The watcher automatically provisions Nginx config + SSL certificate
```

### Removing a site

```bash
# Remove the directory — config and certificate are cleaned up
rm -rf /var/www/example.com
```

## License

GPL-3.0 — see [LICENSE](LICENSE).
