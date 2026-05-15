# MusiHub Front Context

## Objetivo
Documento vivo del frontend de MusiHub.

Sirve para recordar el contexto, el plan y las decisiones tomadas mientras se construye la app movil Flutter del TFG.

## Forma de trabajo acordada
- Avanzar poco a poco.
- Explicar cada archivo, carpeta, comando y decision antes o justo despues de usarlo.
- No aplicar cambios de codigo directamente por defecto.
- Flujo preferido: propuesta breve -> revision del usuario -> aplicar solo si el usuario lo pide.
- En cada nueva consulta, atender primero a las directrices y al contexto vivo antes de proponer o implementar.
- Antes de una tarea de implementacion, presentar un plan claro, explicar que se va a hacer, por que y en que pasos, de forma entendible para el usuario.
- Evitar scaffolding grande salvo que sea el generado base por Flutter.
- No introducir arquitectura compleja antes de necesitarla.
- Priorizar una app real de MusiHub frente a ejemplos aislados.
- Si para el frontend hace falta informacion del backend que no este clara o no se pueda leer directamente, pedir al usuario exactamente el dato necesario para que lo consulte/pase desde el backend.
- Limitar este chat a trabajo del frontend. Si aparece un problema que probablemente sea del backend, explicarlo como bloqueo externo, indicar por que apunta al backend y pedir al usuario que lo valide en el chat/carpeta del backend. No modificar backend desde este contexto salvo peticion explicita.

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
- Flutter ya esta disponible desde terminal:
  - Flutter `3.41.9`.
  - Dart `3.11.5`.
- Android toolchain quedo preparado para desarrollo Android.
- Chrome esta disponible para comprobaciones con Flutter web.
- La base generada por Flutter fue sustituida por una app minima de MusiHub.
- El frontend ya conecta con backend real para:
  - auth,
  - perfil y catalogos,
  - anuncios,
  - busqueda/filtros minimos de anuncios.
- Primer bloque visual desde Figma iniciado:
  - tema global de MusiHub,
  - pantalla de publicar/editar anuncio adaptada parcialmente al frame `54:1511 Publicar`.
- Feed/listado de oportunidades adaptado parcialmente a la captura/frame `99:414 Inicio`:
  - buscador visual,
  - chips rapidos de tipo,
  - filtros avanzados plegables,
  - tarjetas de anuncio,
  - bottom navigation.
- Detalle de anuncio adaptado parcialmente a Figma:
  - chips de tipo/instrumento/estilo,
  - datos de localizacion, fecha y precio,
  - descripcion en bloque visual,
  - autor provisional como `Usuario #author_user_id`,
  - boton `Contactar` pintado sin funcionalidad real por ahora.
- La validacion actual se mantiene con:
  - `flutter analyze`: sin problemas.
  - `flutter test`: test de login y query params de filtros correcto.

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

## Fase Flutter actual
Objetivo: conectar Flutter -> FastAPI -> PostgreSQL con flujos reales, sin construir todavia una arquitectura grande ni el diseno final.

Ya esta implementado de forma minima:

- auth,
- perfil y catalogos,
- anuncios,
- busqueda/filtros minimos de anuncios.

No se implementa todavia:

- favoritos,
- bandas,
- alertas,
- FCM,
- paginacion,
- busqueda por texto libre,
- orden avanzado,
- diseno final.

Nota de diseno: existen pantallas creadas en Figma que se replicaran mas adelante. Hasta entonces las pantallas Flutter deben ser simples, utiles para probar funcionalidad real y faciles de entender.

## Primer hito tecnico completado
Validar este flujo:

```text
Login Flutter -> POST /auth/login -> guardar token -> GET /auth/me -> Feed
```

Por que este flujo primero:

- comprueba que Flutter llega al backend,
- comprueba que FastAPI responde,
- comprueba que el JWT se guarda en el dispositivo,
- comprueba que el token se envia en `Authorization`,
- comprueba que PostgreSQL devuelve un usuario real.

Este hito ya esta completado. Tambien se anadieron registro minimo, autoentrada con token, perfil/catalogos y anuncios.

## Estructura actual del codigo propio

```text
lib/
  main.dart
  core/
    config/
      api_config.dart
    api/
      api_client.dart
    catalog/
      catalog_item.dart
    session/
      token_store.dart
    theme/
      musihub_theme.dart
  features/
    auth/
      auth_api.dart
      login_screen.dart
      register_screen.dart
      session_gate.dart
    profile/
      profile_api.dart
      profile_screen.dart
    opportunities/
      opportunities_api.dart
      opportunity_display.dart
      opportunities_list_screen.dart
      opportunity_detail_screen.dart
      my_opportunities_screen.dart
      opportunity_form_screen.dart
      widgets/
        opportunity_feed_widgets.dart
```

Significado:

- `main.dart`: punto de entrada de Flutter.
- `core/config/`: valores de configuracion, como la URL base de la API.
- `core/api/`: cliente HTTP comun.
- `core/catalog/`: modelos compartidos de catalogos usados por mas de una feature.
- `core/session/`: lectura y escritura del token.
- `core/theme/`: tema visual global de MusiHub basado en Figma.
- `features/auth/`: pantallas y llamadas de autenticacion.
- `features/profile/`: pantalla y API del perfil musical.
- `features/opportunities/`: pantallas y API de anuncios.

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

## Archivos principales del primer bloque de codigo

```text
pubspec.yaml
lib/main.dart
lib/core/config/api_config.dart
lib/core/api/api_client.dart
lib/core/catalog/catalog_item.dart
lib/core/session/token_store.dart
lib/core/theme/musihub_theme.dart
lib/features/auth/auth_api.dart
lib/features/auth/login_screen.dart
lib/features/auth/register_screen.dart
lib/features/auth/session_gate.dart
lib/features/profile/profile_api.dart
lib/features/profile/profile_screen.dart
lib/features/opportunities/opportunities_api.dart
lib/features/opportunities/opportunity_display.dart
lib/features/opportunities/opportunities_list_screen.dart
lib/features/opportunities/opportunity_detail_screen.dart
lib/features/opportunities/my_opportunities_screen.dart
lib/features/opportunities/opportunity_form_screen.dart
test/widget_test.dart
```

Solo si Android bloquea HTTP local durante desarrollo:

```text
android/app/src/main/AndroidManifest.xml
```

## Archivos propios creados
- `lib/core/config/api_config.dart`: centraliza la URL base del backend y permite cambiarla con `--dart-define=API_BASE_URL=...`.
- `lib/core/api/api_client.dart`: cliente HTTP minimo para construir URLs, enviar `GET`/`POST` en JSON y anadir `Authorization: Bearer <token>` cuando exista token.
- `lib/core/catalog/catalog_item.dart`: modelo comun para elementos de catalogo con `id` y `name`, usado por perfil y anuncios.
- `lib/core/session/token_store.dart`: guarda, lee y borra el JWT usando `flutter_secure_storage`.
- `lib/core/theme/musihub_theme.dart`: tema visual global con colores, tipografias aproximadas, estilos de inputs, botones y chips inspirados en Figma.
- `lib/features/auth/auth_api.dart`: implementa el contrato real de auth contra FastAPI:
  - `POST /auth/login`
  - `POST /auth/register`
  - `GET /auth/me`
  - modelo simple `AuthUser` con `id`, `email`, `fullName` y `role`.
- `lib/features/auth/login_screen.dart`: pantalla minima de login, sin diseno final, con email, contrasena y boton para validar auth real.
- `lib/features/auth/register_screen.dart`: pantalla minima de registro, sin diseno final, con email, contrasena, nombre completo y rol.
- `lib/features/auth/session_gate.dart`: puerta de arranque que lee el token guardado, valida `/auth/me` y decide entre login o feed de anuncios.
- `lib/features/profile/profile_api.dart`: implementa catalogos y perfil contra FastAPI:
  - `GET /catalogs/instruments`
  - `GET /catalogs/music-styles`
  - `GET /profile/me`
  - `PUT /profile/me`
- `lib/features/profile/profile_screen.dart`: pantalla minima de crear/editar perfil, carga catalogos, lee perfil actual, rellena formulario y guarda el perfil completo.
- `lib/features/opportunities/opportunities_api.dart`: implementa la capa API minima de anuncios contra FastAPI:
  - `GET /catalogs/opportunity-types`
  - `GET /opportunities`, con filtros opcionales por query params
  - `GET /opportunities/{id}`
  - `GET /opportunities/me`
  - `POST /opportunities`
  - `PATCH /opportunities/{id}`
  - `PATCH /opportunities/{id}/close`
- `lib/features/opportunities/opportunity_display.dart`: helpers de presentacion de anuncios para etiquetas de tipos, colores de chips, fechas y precios, compartidos por feed, detalle y formulario.
- `lib/features/opportunities/opportunities_list_screen.dart`: pantalla minima de listado publico de anuncios activos, con filtros por tipo, ciudad, provincia, instrumento, estilo, fecha y precio.
- `lib/features/opportunities/widgets/opportunity_feed_widgets.dart`: widgets visuales reutilizables del feed de anuncios: buscador visual, chips rapidos, filtros plegables, cards y barra inferior.
- `lib/features/opportunities/opportunity_detail_screen.dart`: pantalla minima de detalle publico de un anuncio.
- `lib/features/opportunities/my_opportunities_screen.dart`: pantalla minima de anuncios del usuario autenticado usando `GET /opportunities/me`.
- `lib/features/opportunities/opportunity_form_screen.dart`: formulario minimo de creacion/edicion de anuncios usando tipos, instrumentos, estilos, `POST /opportunities` y `PATCH /opportunities/{id}`.
- `WINDOWS_SETUP.md`: pasos para preparar backend, frontend y pruebas en Windows.
- `CODEX_WINDOWS_FRONT_PROMPT.md`: prompt exacto para continuar el front en un nuevo chat de Codex desde Windows.

## Estado de validacion del frontend
- La app contador generada por Flutter se sustituyo por una pantalla minima de MusiHub.
- Login real validado contra backend tras corregir el bloqueo CORS en el backend desde su propio contexto.
- Registro minimo anadido en frontend. Flujo previsto: crear cuenta -> volver a login -> iniciar sesion.
- Autoentrada anadida: al abrir la app se lee el token guardado; si `/auth/me` responde bien se entra en el feed de anuncios, si falla se borra el token y se vuelve a Login.
- Perfil/catalogos conectados en frontend: desde la barra inferior del feed se puede abrir una pantalla minima de perfil, cargar instrumentos/estilos, leer `GET /profile/me` y guardar con `PUT /profile/me`.
- Perfil/catalogos validado contra backend real: los endpoints funcionan correctamente desde el flujo del front.
- Pantalla de perfil ajustada como pantalla real: primero muestra el perfil en modo lectura y desde ahi permite editar perfil, abrir `Mis anuncios` o cerrar sesion.
- Anuncios iniciado en frontend: existe capa API y modelos para tipos, listado, detalle, mis anuncios, crear, editar y cerrar.
- Lectura publica de anuncios conectada en UI: el feed es la pantalla principal privada y lista anuncios activos con acceso al detalle.
- Mis anuncios conectado en UI: desde Perfil se puede abrir `Mis anuncios` y listar anuncios propios activos y cerrados.
- Creacion de anuncios conectada en UI: desde la barra inferior del feed o desde `Mis anuncios` se puede abrir `Crear anuncio`, cargar catalogos, validar reglas basicas por tipo y enviar `POST /opportunities`.
- Edicion y cierre de anuncios conectado en UI: desde `Mis anuncios`, si el anuncio esta activo, se puede editar con `PATCH /opportunities/{id}` o cerrar con `PATCH /opportunities/{id}/close`.
- Busqueda/filtros minimos de anuncios conectados en UI: el listado publico carga catalogos, permite aplicar/limpiar filtros y construye query params solo para campos rellenados.
- Diseno Figma iniciado en frontend: `OpportunityFormScreen` usa el tema global y se adapta de forma inicial al frame `54:1511 Publicar`.
- Feed Figma iniciado en frontend: `OpportunitiesListScreen` usa cards, chips, buscador visual y barra inferior inspirados en `99:414 Inicio`.
- Detalle Figma iniciado en frontend: `OpportunityDetailScreen` muestra el anuncio con chips, resumen de datos, descripcion, autor provisional y boton de contacto visual.
- Elementos de Figma sin backend actual se pueden pintar sin funcionalidad real:
  - buscador por texto,
  - favoritos/corazon,
  - guardados,
  - compartir,
  - contactar.
- En detalle de anuncio se muestra solo `event_date`; no se muestra hora porque backend todavia no devuelve hora del evento.
- En detalle de anuncio se muestra `Usuario #author_user_id` porque backend todavia no devuelve nombre/rol publico del autor.
- Mensajes de error mantenidos genericos: no se filtran casos concretos todavia.
- `flutter analyze`: sin problemas.
- `flutter test`: test de pantalla de login y construccion de query params correcto.

## Referencias Figma detectadas
Archivo principal:

```text
https://www.figma.com/design/CElnEU093hpHlotpzsuIHj/Dise%C3%B1o-MusiHub
```

Nodos ya revisados:

- `51:225` - `Style Guide`: tipografias y colores base.
- `51:226` - `Frame 1`: detalle de style guide:
  - H1: Akatab Black 32.
  - H2: Akatab Bold 22.
  - H3: Akatab SemiBold 15.
  - H4: Akatab SemiBold 12.
  - Color principal validado para MusiHub: lila/azul suave `#737DFF`, el usado por el filtro activo del feed, por ejemplo `Todos`.
  - Gris observado: `#6B6B6B`.
- `94:255` - `Screens`: contenedor con pantallas de publicar y alertas.
- `54:1511` - `Publicar`: referencia principal para `OpportunityFormScreen`.
- `84:340` - `Alertas`: referencia futura para pantalla de alertas.
- `84:257` - `Pantalla orig 5`: onboarding/configuracion inicial de alertas.
- `99:326` - `Feed`: contenedor probable de feed/listado; pendiente de lectura detallada por limite MCP.
- `99:414` - `Inicio`: pantalla de inicio/feed detectada dentro de `Feed`; se uso captura del usuario como referencia visual.
- `104:326` / `104:327`: contenedor/pantalla probable de gestion de banda; pendiente de lectura detallada.

Decisiones de diseno actuales:

- No convertir Figma automaticamente a Flutter.
- Usar Figma como referencia visual principal para colores, posicion, tamanos, jerarquia y estilo, pero no seguirlo a rajatabla si no encaja con la funcionalidad real ya implementada.
- Se permite adaptar pantallas con sentido comun cuando falten elementos funcionales en Figma, sobren elementos sin backend actual o una composicion no funcione bien en Flutter.
- Ejemplo validado: si el diseno muestra solo algunos filtros rapidos pero el backend/front soporta mas tipos utiles, se pueden anadir o ajustar esos filtros para que la pantalla sea coherente con MusiHub.
- Si una adaptacion visual/funcional no es obvia o puede cambiar el criterio de producto, pedir validacion antes de implementarla.
- Avanzar pantalla por pantalla.
- Si una pieza de Figma aun no tiene soporte funcional/backend, se puede pintar y dejar sin accion real o con aviso simple de "mas adelante".
- El color principal de marca en Flutter es `MusiHubColors.primary = #737DFF`; debe usarse en botones principales, chips seleccionados, foco de inputs y estados activos.
- No anadir todavia librerias de diseno ni `google_fonts`; si se quiere usar Akatab real, mas adelante se anadiran assets de fuente o una decision explicita de dependencia.

## Siguiente paso recomendado
Antes del siguiente bloque funcional:

1. Cerrar commit limpio del frontend actual.
2. Mantener fuera del commit los cambios no relacionados de backend o raiz del repo.
3. Validar manualmente filtros principales contra backend real.
4. No empezar todavia FCM, bandas, favoritos ni diseno final de Figma.
