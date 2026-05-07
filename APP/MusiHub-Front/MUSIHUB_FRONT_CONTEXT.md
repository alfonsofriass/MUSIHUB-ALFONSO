# MusiHub Front Context

## Objetivo
Documento vivo del frontend de MusiHub.

Sirve para recordar el contexto, el plan y las decisiones tomadas mientras se construye la app movil Flutter del TFG.

## Forma de trabajo acordada
- Avanzar poco a poco.
- Explicar cada archivo, carpeta, comando y decision antes o justo despues de usarlo.
- No aplicar cambios de codigo directamente por defecto.
- Flujo preferido: propuesta breve -> revision del usuario -> aplicar solo si el usuario lo pide.
- Evitar scaffolding grande salvo que sea el generado base por Flutter.
- No introducir arquitectura compleja antes de necesitarla.
- Priorizar una app real de MusiHub frente a ejemplos aislados.
- Si para el frontend hace falta informacion del backend que no este clara o no se pueda leer directamente, pedir al usuario exactamente el dato necesario para que lo consulte/pase desde el backend.

## Vision del producto
MusiHub es una app movil para la comunidad musical.

El MVP completo incluye:
- autenticacion,
- perfil,
- anuncios,
- busqueda y filtros,
- favoritos,
- bandas,
- alertas.

El valor principal del producto es combinar perfiles musicales estructurados, publicaciones tipificadas, busqueda con filtros y alertas personalizadas.

## Orden funcional validado
1. Identidad.
2. Perfil y catalogos.
3. Anuncios.
4. Busqueda.
5. Bandas.
6. Alertas.

## Stack acordado
- Frontend movil: Flutter.
- Backend API: FastAPI.
- Base de datos: PostgreSQL.
- Autenticacion inicial: email/password + JWT.
- Notificaciones push: FCM mas adelante, no ahora.

## Estado actual del frontend
- La carpeta `MusiHub-Front` ya contiene una app Flutter generada con nombre interno `musihub_front`.
- Ya existe `pubspec.yaml`.
- Ya existe carpeta `lib/`.
- Ya existe carpeta `android/`.
- La base generada por Flutter ha sido validada con:
  - `flutter analyze`: sin problemas.
  - `flutter test`: test inicial correcto.
- El siguiente paso es anadir dependencias minimas y preparar el primer login real contra el backend.
- Comprobacion local inicial realizada el 2026-05-05: `flutter doctor` devolvia `command not found`.
- Flutter ya esta disponible desde terminal:
  - Flutter `3.41.9`.
  - Dart `3.11.5`.
- `flutter doctor` detecta que falta Android SDK, asi que todavia no se puede ejecutar la app en emulador Android.
- Chrome aparece disponible, por lo que se puede usar Flutter web como comprobacion inicial si hace falta.

## Estado actual del backend relevante para el front
El backend FastAPI ya tiene autenticacion real funcionando:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`

Backend local:

- Web/escritorio/local: `http://127.0.0.1:8000/api/v1`
- Emulador Android: `http://10.0.2.2:8000/api/v1`

Motivo: dentro del emulador Android, `127.0.0.1` apunta al propio emulador, no al PC donde corre FastAPI.

## Contrato actual de auth

### Registro
Endpoint:

```text
POST /api/v1/auth/register
```

Payload:

```json
{
  "email": "test@example.org",
  "password": "password123",
  "full_name": "Usuario Test",
  "role": "musico"
}
```

Roles validos:

- `musico`
- `venta`
- `sala_bar`
- `academia_profesor`

Respuesta esperada:

```json
{
  "email": "...",
  "full_name": "...",
  "role": "musico",
  "message": "..."
}
```

### Login
Endpoint:

```text
POST /api/v1/auth/login
```

Payload:

```json
{
  "email": "test@example.org",
  "password": "password123"
}
```

Respuesta esperada:

```json
{
  "access_token": "...",
  "token_type": "bearer"
}
```

### Usuario actual
Endpoint:

```text
GET /api/v1/auth/me
```

Header:

```text
Authorization: Bearer <TOKEN>
```

Respuesta real probada:

```json
{
  "id": 5,
  "email": "test1@example.org",
  "full_name": "Usuario Test",
  "role": "musico"
}
```

## Fase 2 Flutter minima
Objetivo: conectar Flutter -> FastAPI -> PostgreSQL usando auth real.

No se implementa todavia:

- perfil,
- catalogos,
- anuncios,
- busqueda,
- favoritos,
- bandas,
- alertas,
- FCM,
- diseno final.

Nota de diseno: existen pantallas creadas en Figma que se replicaran mas adelante. En esta fase las pantallas Flutter deben ser lo mas simples posible y centrarse en validar funcionamiento real.

## Primer hito tecnico
Validar este flujo:

```text
Login Flutter -> POST /auth/login -> guardar token -> GET /auth/me -> Home
```

Por que este flujo primero:

- comprueba que Flutter llega al backend,
- comprueba que FastAPI responde,
- comprueba que el JWT se guarda en el dispositivo,
- comprueba que el token se envia en `Authorization`,
- comprueba que PostgreSQL devuelve un usuario real.

Despues de eso se anadira registro minimo.

## Estructura minima propuesta

```text
lib/
  main.dart
  app/
    musihub_app.dart
  core/
    config/
      api_config.dart
    api/
      api_client.dart
    session/
      token_store.dart
  features/
    auth/
      auth_api.dart
      login_screen.dart
      register_screen.dart
    home/
      home_screen.dart
```

Significado:

- `main.dart`: punto de entrada de Flutter.
- `app/`: configuracion general de la app y navegacion minima.
- `core/config/`: valores de configuracion, como la URL base de la API.
- `core/api/`: cliente HTTP comun.
- `core/session/`: lectura y escritura del token.
- `features/auth/`: pantallas y llamadas de autenticacion.
- `features/home/`: primera pantalla privada tras iniciar sesion.

## Dependencias minimas propuestas

```text
http
flutter_secure_storage
```

Motivo:

- `http`: suficiente para llamar a FastAPI.
- `flutter_secure_storage`: forma sencilla y mas razonable de guardar un JWT que `shared_preferences`.

No se anaden por ahora:

- `go_router`,
- `riverpod`,
- `bloc`,
- `firebase_messaging`,
- librerias de diseno.

Estado:

- `http` anadido a `pubspec.yaml`.
- `flutter_secure_storage` anadido a `pubspec.yaml`.
- Tras anadirlas:
  - `flutter analyze`: sin problemas.
  - `flutter test`: test inicial correcto.

## Comandos previstos
Desde la carpeta `MusiHub-Front`:

```bash
flutter doctor
flutter create --platforms=android .
flutter pub add http flutter_secure_storage
```

Para ejecutar en emulador Android:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Para ejecutar en web o escritorio:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

## Archivos que se tocarian en el primer bloque de codigo

```text
pubspec.yaml
lib/main.dart
lib/app/musihub_app.dart
lib/core/config/api_config.dart
lib/core/api/api_client.dart
lib/core/session/token_store.dart
lib/features/auth/auth_api.dart
lib/features/auth/login_screen.dart
lib/features/home/home_screen.dart
test/widget_test.dart
```

Solo si Android bloquea HTTP local durante desarrollo:

```text
android/app/src/main/AndroidManifest.xml
```

## Archivos propios creados
- `lib/core/config/api_config.dart`: centraliza la URL base del backend y permite cambiarla con `--dart-define=API_BASE_URL=...`.
- `lib/core/api/api_client.dart`: cliente HTTP minimo para construir URLs, enviar `GET`/`POST` en JSON y anadir `Authorization: Bearer <token>` cuando exista token.
- `lib/core/session/token_store.dart`: guarda, lee y borra el JWT usando `flutter_secure_storage`.
- `lib/features/auth/auth_api.dart`: implementa el contrato real de auth contra FastAPI:
  - `POST /auth/login`
  - `GET /auth/me`
  - modelo simple `AuthUser` con `id`, `email`, `fullName` y `role`.
- `lib/features/auth/login_screen.dart`: pantalla minima de login, sin diseno final, con email, contrasena y boton para validar auth real.
- `lib/features/home/home_screen.dart`: pantalla privada minima que muestra los datos devueltos por `/auth/me` y permite borrar el token.
- `WINDOWS_SETUP.md`: pasos para preparar backend, frontend y pruebas en Windows.
- `CODEX_WINDOWS_FRONT_PROMPT.md`: prompt exacto para continuar el front en un nuevo chat de Codex desde Windows.

## Estado de validacion del frontend
- La app contador generada por Flutter se sustituyo por una pantalla minima de MusiHub.
- `flutter analyze`: sin problemas.
- `flutter test`: test de pantalla de login correcto.

## Decision pendiente inmediata
Antes de escribir el login real:

1. Explicar que es `pubspec.yaml`, `lib/`, `android/` y `test/`.
2. Anadir dependencias minimas:
   - `http`
   - `flutter_secure_storage`
3. Sustituir la app contador generada por Flutter por una pantalla minima de MusiHub.
4. Implementar solo login + `/auth/me`.
