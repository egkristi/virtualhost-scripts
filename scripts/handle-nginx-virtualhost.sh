#!/bin/bash
set -euo pipefail

WATCHED_FOLDER="${1:?Usage: $0 <watched_folder> <event> <changed>}"
EVENT="${2:?Usage: $0 <watched_folder> <event> <changed>}"
CHANGED="${3:?Usage: $0 <watched_folder> <event> <changed>}"

NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
LETSENCRYPT_LIVE="/etc/letsencrypt/live"

enable_ssl_in_config() {
	local SITE="$1"
	local CONF="${NGINX_SITES_AVAILABLE}/${SITE}.conf"
	if [ -f "$CONF" ]; then
		sed -i \
			-e "s|# ssl_certificate |ssl_certificate |" \
			-e "s|# ssl_certificate_key |ssl_certificate_key |" \
			-e "s|# ssl_stapling |ssl_stapling |" \
			"$CONF"
	fi
}

new_virtualhost() {
	local SITE_FOLDER="$1"
	local SITE="$2"
	local SITE_ROOT="${SITE_FOLDER}/${SITE}"

	if [ -z "$(dig +short "${SITE}")" ]; then
		echo "Non-existing site: ${SITE} (DNS does not resolve)"
		return 1
	fi

	chmod -R 750 "${SITE_ROOT}"
	touch "${SITE_ROOT}/index.php"

	cat <<-EOF > "${NGINX_SITES_AVAILABLE}/${SITE}.conf"
	server {
	    listen 80;
	    server_name ${SITE} www.${SITE};
	    access_log /var/log/nginx/${SITE}-http-access.log;
	    error_log  /var/log/nginx/${SITE}-http-error.log error;
	    rewrite ^ https://${SITE}\$request_uri? permanent;
	}

	server {
	    listen 443 ssl http2;
	    server_name ${SITE} www.${SITE};

	    access_log /var/log/nginx/${SITE}-https-access.log;
	    error_log  /var/log/nginx/${SITE}-https-error.log error;

	    # ssl_certificate ${LETSENCRYPT_LIVE}/${SITE}/fullchain.pem;
	    # ssl_certificate_key ${LETSENCRYPT_LIVE}/${SITE}/privkey.pem;
	    # ssl_stapling on;

	    root ${SITE_ROOT};
	    index index.php index.html;
	}
	EOF

	ln -sf "${NGINX_SITES_AVAILABLE}/${SITE}.conf" "${NGINX_SITES_ENABLED}/${SITE}.conf"

	if nginx -t; then
		nginx -s reload
		if certbot certonly --webroot -w "${SITE_ROOT}" -d "${SITE}" -d "www.${SITE}"; then
			enable_ssl_in_config "${SITE}"
			if nginx -t; then
				nginx -s reload
				echo "SSL enabled for ${SITE}"
			else
				echo "Warning: nginx config invalid after enabling SSL for ${SITE}" >&2
			fi
		else
			echo "Warning: certbot failed for ${SITE}, site available on HTTP only" >&2
		fi
	else
		echo "Error: nginx config test failed for ${SITE}" >&2
		rm -f "${NGINX_SITES_ENABLED}/${SITE}.conf"
		rm -f "${NGINX_SITES_AVAILABLE}/${SITE}.conf"
		return 1
	fi
}

remove_virtualhost() {
	local SITE_FOLDER="$1"
	local SITE="$2"

	rm -f "${NGINX_SITES_ENABLED}/${SITE}.conf"
	rm -f "${NGINX_SITES_AVAILABLE}/${SITE}.conf"

	if nginx -t; then
		nginx -s reload
	fi

	if [ -d "${LETSENCRYPT_LIVE}/${SITE}" ]; then
		certbot delete --cert-name "${SITE}" --non-interactive 2>/dev/null || true
	fi
}

case "${EVENT}" in
	"CREATE,ISDIR"|"MOVED_TO,ISDIR")
		new_virtualhost "${WATCHED_FOLDER}" "${CHANGED}"
		;;
	"DELETE,ISDIR"|"MOVED_FROM,ISDIR")
		remove_virtualhost "${WATCHED_FOLDER}" "${CHANGED}"
		;;
	*)
		echo "Unknown event: ${EVENT}" >&2
		;;
esac