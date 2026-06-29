-- init-db.sql
-- Se ejecuta automáticamente la primera vez que arranca el contenedor de MySQL.
-- MYSQL_DATABASE ya crea "users_db"; aquí creamos también "products_db"
-- porque el backend de productos (Python/Flask) la necesita.

CREATE DATABASE IF NOT EXISTS products_db;
