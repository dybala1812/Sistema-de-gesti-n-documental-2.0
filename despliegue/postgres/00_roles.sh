#!/bin/sh
# Lo ejecuta la imagen de PostgreSQL la PRIMERA vez que crea la base (docker-entrypoint-initdb.d).
# Crea los mismos roles que usa Supabase, para que las migraciones y el backend funcionen igual:
#   anon / authenticated : sin acceso a nada (las migraciones les quitan permisos)
#   service_role         : el que usa el backend; salta RLS, como en Supabase
#   authenticator        : con el que PostgREST se conecta y cambia al rol del token
set -eu
psql -v ON_ERROR_STOP=1 -v clave="$AUTHENTICATOR_PASSWORD" --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create role authenticator login noinherit password :'clave';
grant anon, authenticated, service_role to authenticator;
grant usage on schema public to service_role;
alter default privileges in schema public grant all on tables to service_role;
alter default privileges in schema public grant all on sequences to service_role;
alter default privileges in schema public grant execute on functions to service_role;
SQL
