#!/bin/bash
set -e
WATCHED_FOLDER=${1}
EVENT=${2}
CHANGED=${3}

NGINX_SITES_AVAILABLE="/etc/nginx/sites-available" #krever nginx installert
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
LETSENCRYPT_LIVE="/etc/letsencrypt/live" #krever letsencrypt certbot installert: https://certbot.eff.org/docs/install.html

new_virtualhost(){	
SITE_FOLDER=${1}
SITE=${2}
if [ ! -z "$(dig +short "${SITE}")" ]; then #sjekker om domenet resolver
	chmod -R 755 ${SITE_FOLDER}${SITE}
	touch ${SITE_FOLDER}${SITE}/index.php
cat << EOF > /${NGINX_SITES_AVAILABLE}/${SITE}.conf
server {
    listen 80;
    server_name ${SITE} www.${SITE};
	access_log /var/log/nginx/${SITE}-http-access.log;
	error_log  /var/log/nginx/${SITE}-http-error.log error;
    rewrite ^ https://${SITE}$request_uri? permanent;
}

server {
    listen 443 ssl http2;
	server_name ${SITE} www.${SITE};

	access_log /var/log/nginx/${SITE}-https-access.log;
	error_log  /var/log/nginx/${SITE}-https-error.log error;

    # ssl_certificate ${LETSENCRYPT_LIVE}/${SITE}/fullchain.pem;
    # ssl_certificate_key ${LETSENCRYPT_LIVE}/${SITE}/privkey.pem;
    # ssl_stapling on;
    
    root ${SITE_FOLDER}${SITE};
	index index.php index.html;
}
EOF

	ln -s ${NGINX_SITES_AVAILABLE}/${SITE}.conf ${NGINX_SITES_ENABLED}/${SITE}.conf
	if nginx -t; then
		nginx -s reload
		# https://certbot.eff.org/docs/using.html
		#certbot --nginx -d ${SITE} -d www.${SITE}
		certbot certonly --webroot -w ${SITE_FOLDER}${SITE} -d ${SITE} -d www.${SITE}
	else
		#cat ${NGINX_SITES_ENABLED}/${SITE}.conf
		rm ${NGINX_SITES_ENABLED}/${SITE}.conf
	fi
else
	echo "Non-existing site: ${SITE}"
fi
}

remove_virtualhost(){
	SITE_FOLDER=${1}
	SITE=${2}
	rm ${NGINX_SITES_ENABLED}/${SITE}.conf
	nginx -s reload
	rm -rf ${LETSENCRYPT_LIVE}/${SITE}
}

case ${EVENT} in
	"CREATE,ISDIR")
		#Create new virtual host ${CHANGED}
		new_virtualhost ${WATCHED_FOLDER} ${CHANGED}
	;;
	"DELETE,ISDIR")
		#Remove virtual host ${CHANGED}
		remove_virtualhost ${WATCHED_FOLDER} ${CHANGED}
	;;
	"MOVED_TO,ISDIR")
		#Create new virtual host ${CHANGED}
		new_virtualhost ${WATCHED_FOLDER} ${CHANGED}
	;;
	"MOVED_FROM,ISDIR")
		#Remove virtual host ${CHANGED}
		remove_virtualhost ${WATCHED_FOLDER} ${CHANGED}
	;;
	*)
		echo "unknown event"
	;;
esac