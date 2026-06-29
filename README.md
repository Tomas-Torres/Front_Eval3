# Frontend - Gestión de Productos

Frontend en HTML/CSS/JS plano, servido por **Nginx** dentro de un contenedor Docker. Consume dos APIs REST (usuarios y productos) desarrolladas por el equipo.

## Por qué se cambió de Java/Maven a HTML estático + Nginx

La versión anterior generaba el HTML una sola vez con `mvn exec:java`, y las URLs de los backends quedaban "quemadas" dentro del JavaScript en tiempo de compilación. Esto funciona para abrir el archivo localmente, pero no es compatible con el objetivo de la evaluación: el frontend debe **ejecutarse como un servicio dentro de un contenedor**, desplegable en AWS, y las URLs de los backends deben poder cambiar (de local a producción) **sin reconstruir la imagen**.

Por eso ahora:
- El HTML/CSS/JS se sirve con **Nginx** (servidor real, liviano, estándar de la industria para contenido estático).
- Las URLs de los backends se inyectan **al iniciar el contenedor**, vía variables de entorno (`BACKEND_USERS_URL`, `BACKEND_PRODUCTS_URL`), no en tiempo de build.

## Arquitectura del contenedor

```
Dockerfile (multietapa)
├── Etapa "build": valida que existan los archivos fuente (alpine, sin nginx)
└── Etapa "runtime": nginx:alpine + gettext (para envsubst)
        └── docker-entrypoint.sh genera config.js a partir de las
            variables de entorno, y luego arranca nginx
```

### Flujo al iniciar el contenedor

1. Docker/ECS inyecta `BACKEND_USERS_URL` y `BACKEND_PRODUCTS_URL` como variables de entorno.
2. `docker-entrypoint.sh` corre `envsubst` sobre `config.js.template` y genera `config.js` real dentro de `/usr/share/nginx/html/`.
3. Nginx arranca y sirve `index.html`, que carga `config.js` y luego `script.js`.
4. `script.js` lee las URLs desde `window.APP_CONFIG` (definido en `config.js`) y hace `fetch()` a los backends.

Esto significa que **la misma imagen Docker** sirve para local, para pruebas y para producción en AWS — solo cambia el valor de las variables de entorno.

## Estructura del proyecto

```
frontend/
├── Dockerfile
├── .dockerignore
├── docker-compose.yml      # levanta frontend + 2 backends + MySQL en local
├── init-db.sql             # crea la 2da base de datos (products_db) en MySQL
└── app/
    ├── index.html
    ├── styles.css
    ├── script.js            # lógica de la app (fetch a las APIs)
    ├── config.js.template   # plantilla con variables ${BACKEND_USERS_URL} etc.
    └── docker-entrypoint.sh # genera config.js real al iniciar el contenedor
```

## Cómo correrlo

### Opción A: solo el frontend (con backends de ejemplo en localhost)

```bash
cd frontend
docker build -t frontend-app .
docker run -p 8080:80 \
  -e BACKEND_USERS_URL=http://localhost:8081 \
  -e BACKEND_PRODUCTS_URL=http://localhost:8082 \
  frontend-app
```

Abrir `http://localhost:8080`.

### Opción B: todo el stack junto (frontend + 2 backends + MySQL)

Requiere tener los 3 repos clonados como carpetas hermanas (ver comentario en `docker-compose.yml`):

```
proyecto/
├── frontend/          (este repo)
├── backJs_Eval3/      (backend de usuarios, Node.js)
└── BackPy_Eval3/      (backend de productos, Python/Flask)
```

```bash
cd frontend
docker compose up --build
```

Esto levanta:
- `mysql` en el puerto 3306
- `backend-usuarios` (Node.js) en el puerto 8081
- `backend-productos` (Python/Flask) en el puerto 8082
- `frontend` (Nginx) en el puerto 8080

Abrir `http://localhost:8080`.

### Apuntar a backends desplegados en AWS

Cuando los backends estén corriendo en AWS (ECS/EKS), solo se cambian las variables de entorno del contenedor del frontend (en `docker-compose.yml`, en `docker run -e`, o en la definición de tarea de ECS):

```bash
docker run -p 8080:80 \
  -e BACKEND_USERS_URL=http://<IP-o-dominio-backend-usuarios>:8081 \
  -e BACKEND_PRODUCTS_URL=http://<IP-o-dominio-backend-productos>:8082 \
  frontend-app
```

No es necesario reconstruir la imagen ni tocar código.

## Buenas prácticas aplicadas en el Dockerfile

- **Multietapa**: separa la etapa de "build" (validación de archivos) de la etapa de runtime, que no lleva ninguna herramienta de build.
- **Imagen base minimalista**: `nginx:1.27-alpine`, no una imagen completa de Linux.
- **`.dockerignore`**: evita copiar `.git`, archivos `.env`, y otros archivos innecesarios a la imagen.
- **Variables de entorno**: ninguna URL ni configuración queda fija en el código; todo se inyecta en tiempo de ejecución.
- **Sin secretos en la imagen**: no hay contraseñas ni claves en este componente (el frontend no se conecta directo a la base de datos).

## Funcionalidades

### Registro de Usuarios
- Formulario de registro con validación de contraseña.
- Envía `POST /api/users/register` al backend de usuarios (Node.js).
- Si el backend no responde, muestra el error correspondiente.

### Visualización de Productos
- Trae los productos con `GET /api/products` desde el backend de productos (Python/Flask).
- Si el backend está desconectado, muestra un catálogo de ejemplo local como respaldo visual (con aviso explícito de que son datos de ejemplo).
- Solo lectura (no se pueden realizar compras).
