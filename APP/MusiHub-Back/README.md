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
- Alertas V1 con push inmediato por FCM: preferencias, matching básico,
  trazabilidad, anti-duplicados y registro de tokens de dispositivo.

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
- `POST /api/v1/device-tokens`
- `POST /api/v1/device-tokens/unregister`
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
  opcional, estado activado/desactivado, tipos de anuncio, instrumentos y
  estilos de interes.
- `opportunity_type_ids: []` significa que no se generan alertas.
- `instrument_ids: []` significa que no se filtra por instrumento.
- `style_ids: []` significa que no se filtra por estilo.
- Al crear un anuncio, el backend evalúa preferencias de otros usuarios y genera
  alertas si hay coincidencia.
- El matching es básico y explicable: tipo, ciudad, provincia, instrumento y estilo.
- Los instrumentos y estilos de alerta son independientes del perfil musical del
  usuario.
- Las alertas se guardan en BD y se evita duplicar la misma alerta para el mismo
  usuario y anuncio.
- Si la preferencia es `immediate`, el backend intenta enviar push por FCM tras
  guardar la alerta.
- Las frecuencias `daily` y `weekly` guardan la alerta en BD, pero el envío
  programado queda para una fase posterior.
- Si FCM falla, no debe fallar la creación del anuncio ni la alerta en BD.

## FCM
- `POST /api/v1/device-tokens` requiere JWT y registra o actualiza el token FCM
  del dispositivo autenticado.
- Payload de registro:

```json
{
  "token": "FCM_TOKEN",
  "platform": "android"
}
```

- `POST /api/v1/device-tokens/unregister` requiere JWT y elimina el token FCM
  del usuario autenticado al hacer logout. Si el token no existe o ya no
  pertenece al usuario, responde correctamente sin error.
- Payload de desregistro:

```json
{
  "token": "FCM_TOKEN"
}
```

- Variables de entorno opcionales:

```env
PUSH_NOTIFICATIONS_ENABLED=true
FIREBASE_CREDENTIALS_PATH=/ruta/privada/service-account.json
FIREBASE_PROJECT_ID=musihub
```

El `service-account.json` es secreto y no debe subirse a Git.

## Migraciones
Head esperado:

```text
b8c9d0e1f2a3
```

## Ejecución local
```bash
docker compose up -d db
alembic upgrade head
uvicorn app.main:app --reload
```

Para probar FCM desde un móvil físico en la misma red, levantar el backend con:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```
