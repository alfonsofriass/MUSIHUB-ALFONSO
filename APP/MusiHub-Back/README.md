# MusiHub Back

Backend FastAPI del TFG MusiHub.

## Stack
- FastAPI
- PostgreSQL
- SQLAlchemy
- Alembic
- JWT

## Estado actual
- Autenticación real con email/password y JWT.
- Perfil de usuario y catálogos musicales.
- Anuncios V1 para usuario individual.
- Búsqueda y filtros básicos sobre anuncios activos.

## Endpoints principales
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/catalogs/instruments`
- `GET /api/v1/catalogs/music-styles`
- `GET /api/v1/catalogs/opportunity-types`
- `GET /api/v1/profile/me`
- `PUT /api/v1/profile/me`
- `POST /api/v1/opportunities`
- `GET /api/v1/opportunities`
- `GET /api/v1/opportunities/me`
- `GET /api/v1/opportunities/{id}`
- `PATCH /api/v1/opportunities/{id}`
- `PATCH /api/v1/opportunities/{id}/close`

## Filtros de anuncios
`GET /api/v1/opportunities` acepta filtros opcionales combinables:

- `type_id`
- `city`
- `province`
- `instrument_id`
- `style_id`
- `date_from`
- `date_to`
- `min_price`
- `max_price`

Las fechas usan formato `YYYY-MM-DD`. El listado público devuelve solo anuncios `active`.

## Migraciones
Head esperado:

```text
b1c2d3e4f5a6
```

## Ejecución local
```bash
docker compose up -d db
alembic upgrade head
uvicorn app.main:app --reload
```
