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
- `GET /api/v1/catalogs/locations`
- `GET /api/v1/profile/me`
- `PUT /api/v1/profile/me`
- `POST /api/v1/profile/me/photo`
- `GET /api/v1/profile/{user_id}`
- `POST /api/v1/opportunities`
- `GET /api/v1/opportunities`
- `GET /api/v1/opportunities/me`
- `GET /api/v1/opportunities/{id}`
- `PATCH /api/v1/opportunities/{id}`
- `PATCH /api/v1/opportunities/{id}/close`
- `PATCH /api/v1/opportunities/{id}/reopen`
- `POST /api/v1/opportunities/{id}/contact-requests`
- `POST /api/v1/opportunities/{id}/favorite`
- `DELETE /api/v1/opportunities/{id}/favorite`
- `GET /api/v1/favorites/me`
- `POST /api/v1/bands`
- `GET /api/v1/bands/me`
- `GET /api/v1/bands/{id}`
- `POST /api/v1/bands/{id}/photo`
- `PATCH /api/v1/bands/{id}/me/visibility`
- `PUT /api/v1/bands/{id}`
- `POST /api/v1/bands/{id}/members`
- `DELETE /api/v1/bands/{id}/members/{user_id}`
- `DELETE /api/v1/bands/{id}`
- `GET /api/v1/alerts/preferences`
- `PUT /api/v1/alerts/preferences`
- `GET /api/v1/alerts/me`
- `POST /api/v1/device-tokens`
- `POST /api/v1/device-tokens/unregister`
- `GET /api/v1/contact-requests/received`
- `GET /api/v1/contact-requests/sent`
- `PATCH /api/v1/contact-requests/{id}/accept`
- `PATCH /api/v1/contact-requests/{id}/reject`
- `GET /api/v1/notifications`
- `PATCH /api/v1/notifications/{id}/read`
- `PATCH /api/v1/notifications/read-all`
- `GET /api/v1/search/profiles`
- `GET /api/v1/search/bands`

## Catálogos
- `GET /api/v1/catalogs/locations` devuelve provincias de Andalucía y varias
  ciudades por provincia para que el front no use texto libre.
- En payloads y filtros se siguen usando `city` y `province` como texto para no
  romper el contrato existente.
- El backend valida contra el catálogo y guarda los nombres canónicos.
- Si se envía `city`, también debe enviarse `province`. `province` sola es válida
  en perfil, bandas, búsqueda y preferencias de alertas.

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
Los filtros `city` y `province` se validan contra el catálogo de ubicaciones.
El dato privado de contacto del anuncio no debería mostrarse a otros usuarios
hasta que exista una solicitud de contacto aceptada.
Las respuestas de anuncios incluyen `author_user` para poder navegar al perfil
público del autor.

## Perfil público
- `POST /api/v1/profile/me/photo` permite subir una imagen de perfil con
  `multipart/form-data`, campo `file`.
- Formatos aceptados: `image/jpeg`, `image/png`, `image/webp`.
- Tamaño máximo: 5 MB.
- La respuesta devuelve `photo_url` como ruta relativa, por ejemplo
  `/uploads/profiles/user_7_xxxxx.jpg`.
- `GET /api/v1/profile/{user_id}` permite consultar el perfil público de otro
  usuario autenticado.
- No devuelve `contact_email` ni `contact_phone`.
- Devuelve `website_url` como enlace público opcional del usuario.
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
- `POST /api/v1/bands/{id}/photo` permite al creador subir una imagen de banda
  con `multipart/form-data`, campo `file`, y devuelve `photo_url`.
- Solo el creador puede editar la banda y gestionar miembros.
- Solo el creador puede eliminar la banda y únicamente si no quedan otros
  miembros. Los anuncios asociados dejan de mostrarse como publicados por banda.
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
- En el MVP solo se acepta `frequency: "immediate"`; las frecuencias diaria y
  semanal quedan como mejora futura.
- El backend intenta enviar push por FCM tras guardar la alerta o una
  notificación de contacto.
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

## Subida de imágenes
- En local, si no hay Supabase Storage configurado, las fotos se guardan en
  `/uploads`.
- En nube, las fotos de perfil y banda se suben a Supabase Storage y `photo_url`
  devuelve una URL pública estable.
- Variables de entorno para Supabase Storage:

```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_SERVICE_ROLE_KEY=clave-service-role
SUPABASE_STORAGE_BUCKET=musihub-uploads
```

`SUPABASE_SERVICE_ROLE_KEY` es secreto y solo debe configurarse en backend.

## Notificaciones In-App
- `GET /api/v1/notifications` devuelve la bandeja del usuario autenticado,
  ordenada por `created_at desc`, junto a `unread_count`.
- `PATCH /api/v1/notifications/{id}/read` marca una notificación propia como
  leída. Si ya estaba leída, no falla.
- `PATCH /api/v1/notifications/read-all` marca todas las notificaciones propias
  pendientes como leídas.
- Tipos iniciales: `alert_match`, `contact_request_received`,
  `contact_request_accepted`, `contact_request_rejected`.
- El campo `data` es opcional y se usa solo como apoyo futuro para enlazar con
  recursos como `opportunity_id` o `contact_request_id`.

## Migraciones
Head esperado:

```text
a3b4c5d6e7f8
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
