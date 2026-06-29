# ---------- Etapa 1: build ----------
# No hay un "build" pesado real (es HTML/CSS/JS plano), pero se deja la
# etapa separada para validar los archivos y mantener el patrón multietapa
# pedido por la pauta. Si en el futuro se agrega un bundler (Vite, etc.),
# esta etapa es donde correría "npm run build".
FROM alpine:3.20 AS build

WORKDIR /build
COPY app/ ./

# Validación simple de que los archivos esenciales existen antes de pasarlos
# a la imagen final (falla rápido si falta algo en el build).
RUN test -f index.html && test -f styles.css && test -f script.js && test -f config.js.template


# ---------- Etapa 2: runtime ----------
# Imagen final minimalista: nginx sobre Alpine, sin herramientas de build.
FROM nginx:1.27-alpine AS runtime

# gettext trae "envsubst", que usamos en el entrypoint para inyectar
# las URLs de los backends como variables de entorno en tiempo de arranque.
RUN apk add --no-cache gettext

# Quitamos la página default de nginx y copiamos solo lo necesario
RUN rm -rf /usr/share/nginx/html/*

COPY --from=build /build/index.html /usr/share/nginx/html/index.html
COPY --from=build /build/styles.css /usr/share/nginx/html/styles.css
COPY --from=build /build/script.js /usr/share/nginx/html/script.js
COPY --from=build /build/config.js.template /usr/share/nginx/html/config.js.template

COPY app/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Variables de entorno por defecto (se pueden sobrescribir en docker-compose,
# docker run -e, o en la definición de tarea de ECS)
ENV BACKEND_USERS_URL=http://localhost:8081
ENV BACKEND_PRODUCTS_URL=http://localhost:8082

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
