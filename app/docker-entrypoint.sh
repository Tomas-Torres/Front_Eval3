#!/bin/sh
# docker-entrypoint.sh
#
# Se ejecuta cada vez que arranca el contenedor del frontend.
# Toma las variables de entorno BACKEND_USERS_URL y BACKEND_PRODUCTS_URL
# (definidas en docker-compose.yml, en `docker run -e ...`, o en la
# definición de la tarea de ECS) y genera config.js dentro de la carpeta
# que sirve Nginx. Así el mismo contenedor/imagen sirve para local,
# desarrollo y producción en AWS, solo cambiando las variables de entorno.

set -e

: "${BACKEND_USERS_URL:=http://localhost:8081}"
: "${BACKEND_PRODUCTS_URL:=http://localhost:8082}"
export BACKEND_USERS_URL BACKEND_PRODUCTS_URL

envsubst '${BACKEND_USERS_URL} ${BACKEND_PRODUCTS_URL}' \
    < /usr/share/nginx/html/config.js.template \
    > /usr/share/nginx/html/config.js

echo "Frontend configurado:"
echo "  BACKEND_USERS_URL=${BACKEND_USERS_URL}"
echo "  BACKEND_PRODUCTS_URL=${BACKEND_PRODUCTS_URL}"

# Ejecuta el comando original del contenedor (nginx en primer plano)
exec "$@"
