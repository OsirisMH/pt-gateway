FROM postgres:16-alpine

# NO fijes POSTGRES_DB a authdb si vas a crear varias
# Deja que el compose lo inyecte o usa "postgres" por defecto

COPY ./sql/ /docker-entrypoint-initdb.d/