# MusiHub Back

Backend de MusiHub, una aplicación móvil orientada a comunidad musical. La API
está desarrollada con FastAPI y utiliza PostgreSQL como base de datos principal.

## Tecnologías

- FastAPI
- PostgreSQL
- SQLAlchemy
- Alembic
- JWT para autenticación
- Firebase Cloud Messaging para notificaciones push
- Supabase Storage para imágenes de perfil y bandas

## Funcionalidades

- Registro e inicio de sesión con email y contraseña.
- Autenticación mediante token JWT.
- Perfil privado y perfil público de usuario.
- Catálogos de instrumentos, estilos musicales, tipos de anuncio y ubicaciones.
- Creación, edición, cierre y reapertura de anuncios.
- Búsqueda y filtrado de anuncios.
- Favoritos.
- Bandas, miembros y visibilidad de bandas en el perfil.
- Solicitudes de contacto para no mostrar datos privados directamente.
- Alertas por coincidencia entre preferencias del usuario y nuevos anuncios.
- Bandeja de notificaciones dentro de la app.
- Registro de tokens FCM para envío de notificaciones push.
- Subida de fotos a almacenamiento externo.

## Estructura

```text
app/
  main.py                  Configuración principal de FastAPI
  db.py                    Conexión a base de datos
  models.py                Modelos SQLAlchemy
  security.py              Hash de contraseñas y JWT
  alert_matching.py        Lógica de coincidencia de alertas
  uploads.py               Validación y subida de imágenes
  push.py                  Envío de notificaciones push
  api/
    router.py              Router principal /api/v1
    routes/                Endpoints por módulo funcional

alembic/
  env.py
  versions/                Migraciones de base de datos

tests/
  test_alert_duplicates.py Prueba anti-duplicados de alertas
```

## Configuración local

Crear un archivo `.env` en la raíz del backend con las variables necesarias:

```env
APP_NAME=MusiHub API
SECRET_KEY=clave_local
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
DATABASE_URL=postgresql+psycopg://musihub:musihub_dev_password@localhost:5432/musihub
```

Para ejecutar PostgreSQL en local:

```bash
docker compose up -d db
```

Aplicar migraciones:

```bash
alembic upgrade head
```

Levantar el backend:

```bash
uvicorn app.main:app --reload
```

La API queda disponible en:

```text
http://127.0.0.1:8000
```

Documentación interactiva:

```text
http://127.0.0.1:8000/docs
```

## Variables opcionales

Para notificaciones push:

```env
PUSH_NOTIFICATIONS_ENABLED=true
FIREBASE_CREDENTIALS_PATH=/ruta/privada/service-account.json
FIREBASE_PROJECT_ID=musihub
```

Para subida de imágenes a Supabase Storage:

```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_SERVICE_ROLE_KEY=clave-service-role
SUPABASE_STORAGE_BUCKET=musihub-uploads
```

Estas claves son privadas y no deben subirse al repositorio.

## Endpoints principales

La API está versionada bajo `/api/v1`.

Autenticación:

- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`

Catálogos:

- `GET /catalogs/instruments`
- `GET /catalogs/music-styles`
- `GET /catalogs/opportunity-types`
- `GET /catalogs/locations`

Perfil:

- `GET /profile/me`
- `PUT /profile/me`
- `POST /profile/me/photo`
- `GET /profile/{user_id}`

Anuncios:

- `POST /opportunities`
- `GET /opportunities`
- `GET /opportunities/me`
- `GET /opportunities/{id}`
- `PATCH /opportunities/{id}`
- `PATCH /opportunities/{id}/close`
- `PATCH /opportunities/{id}/reopen`

Favoritos:

- `POST /opportunities/{id}/favorite`
- `DELETE /opportunities/{id}/favorite`
- `GET /favorites/me`

Bandas:

- `POST /bands`
- `GET /bands/me`
- `GET /bands/{id}`
- `PUT /bands/{id}`
- `POST /bands/{id}/photo`
- `PATCH /bands/{id}/me/visibility`
- `POST /bands/{id}/members`
- `DELETE /bands/{id}/members/{user_id}`
- `DELETE /bands/{id}`

Alertas y notificaciones:

- `GET /alerts/preferences`
- `PUT /alerts/preferences`
- `GET /alerts/me`
- `GET /notifications`
- `PATCH /notifications/{id}/read`
- `PATCH /notifications/read-all`

Contacto:

- `POST /opportunities/{id}/contact-requests`
- `GET /contact-requests/received`
- `GET /contact-requests/sent`
- `PATCH /contact-requests/{id}/accept`
- `PATCH /contact-requests/{id}/reject`

Dispositivos:

- `POST /device-tokens`
- `POST /device-tokens/unregister`

Búsqueda:

- `GET /search/profiles`
- `GET /search/bands`

## Validación

Comprobar sintaxis e imports:

```bash
python -m compileall app tests
```

Comprobar modelos SQLAlchemy:

```bash
python -c "from sqlalchemy.orm import configure_mappers; import app.models; configure_mappers(); print('models ok')"
```

Comprobar migraciones:

```bash
alembic heads
alembic current
```

Ejecutar la prueba anti-duplicados de alertas:

```bash
python -m unittest tests/test_alert_duplicates.py
```

## Base de datos

El esquema funcional está documentado en `db-diagram.txt`. Las migraciones de
Alembic se encuentran en `alembic/versions`.
