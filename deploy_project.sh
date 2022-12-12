#!bin/bash

TRAEFIK_DOMAIN=laravelblog.test

command -v warden >/dev/null 2>&1 || {
    sudo mkdir /opt/warden
    sudo chown $(whoami) /opt/warden
    git clone -b master https://github.com/davidalger/warden.git /opt/warden
    echo 'export PATH="/opt/warden/bin:$PATH"' >> ~/.bashrc
    PATH="/opt/warden/bin:$PATH"
}

command -v warden >/dev/null 2>&1 || {
    echo >&2 "warden is not installed. Aborting."; exit 1;
}

warden svc up

for SERVICE_NAME in "tunnel" "traefik" "portainer" "dnsmasq" "mailhog"
do
    if [ $( docker ps -q --no-trunc | grep $(warden svc ps -q "${SERVICE_NAME}") | wc -l ) -gt 0 ]; then
      echo "$SERVICE_NAME is running"
    else
      echo "$SERVICE_NAME is not running. Use 'warden svc up' and resolve conflicts manually then run this command again"
      exit 1;
    fi
done

if [ -f .env ]
then
    NEW_LARAVEL_ENV_FILE=.env.${RANDOM}
    mv .env "${NEW_LARAVEL_ENV_FILE}"
    echo "\nYour current .env was moved to $NEW_LARAVEL_ENV_FILE"
fi

cp .env.localblog .env

warden env up -d

for SERVICE_NAME in "db" "nginx" "php-fpm"
do
    if [ $( docker ps -q --no-trunc | grep $(warden env ps -q "${SERVICE_NAME}") | wc -l ) -gt 0 ]; then
      echo "$SERVICE_NAME is running"
    else
      echo "$SERVICE_NAME is not running. Use 'warden env up' and resolve conflicts manually then run this command again"
      exit 1;
    fi
done

warden sign-certificate "${TRAEFIK_DOMAIN}"

echo "Starting composer install..."

warden shell -c '
    composer install
'

printf "\n127.0.0.1 ${TRAEFIK_DOMAIN}" | sudo tee -a /etc/hosts
