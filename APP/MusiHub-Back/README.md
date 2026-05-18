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
- Favoritos de anuncios.
- Bandas V1.

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
- `POST /api/v1/opportunities/{id}/favorite`
- `DELETE /api/v1/opportunities/{id}/favorite`
- `GET /api/v1/favorites/me`
- `POST /api/v1/bands`
- `GET /api/v1/bands/me`
- `GET /api/v1/bands/{id}`
- `PUT /api/v1/bands/{id}`
- `POST /api/v1/bands/{id}/members`
- `DELETE /api/v1/bands/{id}/members/{user_id}`

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

## Bandas V1
- La banda no tiene login propio.
- El usuario creador queda como `created_by_user_id`.
- El creador se añade automáticamente como miembro `accepted`.
- Solo el creador puede editar la banda y gestionar miembros.
- Los estilos de banda usan el catálogo `music_styles`.
- No incluye todavía publicación de anuncios como banda.

## Migraciones
Head esperado:

```text
d2e3f4a5b6c7
```

## Ejecución local
```bash
docker compose up -d db
alembic upgrade head
uvicorn app.main:app --reload
```
