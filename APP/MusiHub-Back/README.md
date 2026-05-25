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
- Publicación de anuncios en nombre de banda.
- Alertas V1 sin push real: preferencias, matching básico, trazabilidad y anti-duplicados.

## Endpoints principales
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/catalogs/instruments`
- `GET /api/v1/catalogs/music-styles`
- `GET /api/v1/catalogs/opportunity-types`
- `GET /api/v1/profile/me`
- `PUT /api/v1/profile/me`
- `GET /api/v1/profile/{user_id}`
- `POST /api/v1/opportunities`
- `GET /api/v1/opportunities`
- `GET /api/v1/opportunities/me`
- `GET /api/v1/opportunities/{id}`
- `PATCH /api/v1/opportunities/{id}`
- `PATCH /api/v1/opportunities/{id}/close`
- `POST /api/v1/opportunities/{id}/contact-requests`
- `POST /api/v1/opportunities/{id}/favorite`
- `DELETE /api/v1/opportunities/{id}/favorite`
- `GET /api/v1/favorites/me`
- `POST /api/v1/bands`
- `GET /api/v1/bands/me`
- `GET /api/v1/bands/{id}`
- `PATCH /api/v1/bands/{id}/me/visibility`
- `PUT /api/v1/bands/{id}`
- `POST /api/v1/bands/{id}/members`
- `DELETE /api/v1/bands/{id}/members/{user_id}`
- `GET /api/v1/alerts/preferences`
- `PUT /api/v1/alerts/preferences`
- `GET /api/v1/alerts/me`
- `GET /api/v1/contact-requests/received`
- `GET /api/v1/contact-requests/sent`
- `PATCH /api/v1/contact-requests/{id}/accept`
- `PATCH /api/v1/contact-requests/{id}/reject`
- `GET /api/v1/search/profiles`
- `GET /api/v1/search/bands`

## Filtros de anuncios
`GET /api/v1/opportunities` acepta filtros opcionales combinables:

- `type_id`
- `q`
- `city`
- `province`
- `instrument_id`
- `style_id`
- `date_from`
- `date_to`
- `min_price`
- `max_price`

Las fechas usan formato `YYYY-MM-DD`. El listado público devuelve solo anuncios `active`.
`q` busca texto en título, descripción, ciudad y provincia.
El dato privado de contacto del anuncio no debería mostrarse a otros usuarios
hasta que exista una solicitud de contacto aceptada.
Las respuestas de anuncios incluyen `author_user` para poder navegar al perfil
público del autor.

## Perfil público
- `GET /api/v1/profile/{user_id}` permite consultar el perfil público de otro
  usuario autenticado.
- No devuelve `contact_email` ni `contact_phone`.
- Devuelve las bandas visibles del usuario según `band_members.is_visible_in_profile`.

## Búsqueda de perfiles
`GET /api/v1/search/profiles` requiere token y acepta filtros opcionales
combinables:

- `q`
- `city`
- `province`
- `instrument_id`
- `style_id`

`q` busca en nombre del usuario, biografía, ciudad y provincia.

## Búsqueda de bandas
`GET /api/v1/search/bands` requiere token y acepta filtros opcionales
combinables:

- `q`
- `city`
- `province`
- `style_id`

`q` busca en nombre de la banda, biografía, ciudad y provincia.

## Bandas V1
- La banda no tiene login propio.
- El usuario creador queda como `created_by_user_id`.
- El creador se añade automáticamente como miembro `accepted`.
- Solo el creador puede editar la banda y gestionar miembros.
- Los estilos de banda usan el catálogo `music_styles`.
- Cada miembro puede decidir si muestra u oculta esa banda en su perfil.
- Los anuncios siguen perteneciendo a un usuario, pero pueden indicar `author_band_id`
  para mostrarse como publicados en nombre de una banda del usuario.

## Alertas V1
- El usuario puede guardar preferencias de alertas con frecuencia, ubicación
  opcional, estado activado/desactivado y tipos de anuncio.
- `opportunity_type_ids: []` significa que no se generan alertas.
- Al crear un anuncio, el backend evalúa preferencias de otros usuarios y genera
  alertas si hay coincidencia.
- El matching es básico y explicable: tipo, ciudad, provincia, instrumento y estilo.
- Las alertas se guardan en BD y se evita duplicar la misma alerta para el mismo
  usuario y anuncio.
- FCM y envíos programados quedan para una fase posterior.

## Migraciones
Head esperado:

```text
a7b8c9d0e1f2
```

## Ejecución local
```bash
docker compose up -d db
alembic upgrade head
uvicorn app.main:app --reload
```
