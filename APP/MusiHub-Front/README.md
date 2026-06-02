# MusiHub Front

Frontend movil de MusiHub, app desarrollada en Flutter para el TFG.

## Estado actual

La app esta conectada contra el backend FastAPI real y cubre el MVP principal:

- autenticacion con registro, login, sesion guardada y logout;
- onboarding de registro;
- perfil musical editable, perfil publico y subida de foto de perfil;
- anuncios: feed, detalle, crear, editar, cerrar y reabrir;
- busqueda global sencilla de anuncios, perfiles y bandas;
- filtros de anuncios por catalogos y ubicaciones cerradas;
- favoritos/guardados;
- solicitudes privadas de contacto;
- bandas: crear, ver, editar, invitar miembros, publicar como banda, visibilidad en perfil y subida de foto de banda;
- alertas configurables por tipo, ubicacion, instrumentos y estilos;
- notificaciones push FCM y bandeja simple de notificaciones in-app;
- compartir anuncio y abrir contactos con acciones del sistema cuando sea posible.

El diseno toma Figma como referencia visual, pero se adapta con criterio a la funcionalidad real del MVP.

## Estructura principal

```text
lib/
  main.dart
  core/
    api/
    catalog/
    config/
    forms/
    push/
    session/
    theme/
    uploads/
    widgets/
  features/
    alerts/
    auth/
    bands/
    contact_requests/
    notifications/
    opportunities/
    profile/
    search/
```

Idea general:

- `core/`: piezas compartidas y pequenas, como cliente HTTP, tema, sesion, push, ubicaciones, limites de inputs y widgets comunes.
- `features/`: cada bloque funcional de MusiHub mantiene su pantalla, API y modelos cerca.
- `test/widget_test.dart`: tests basicos de contratos, payloads, parsing y pantalla de login.

## Configuracion de backend

La URL base se define con `API_BASE_URL`.

Chrome o escritorio local:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Emulador Android:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Movil Android fisico:

```bash
flutter run --dart-define=API_BASE_URL=http://IP_DEL_PC:8000/api/v1
```

En movil fisico, el backend debe escuchar en `0.0.0.0` y el movil debe estar en la misma red que el PC.

## Comandos utiles

```bash
flutter pub get
flutter analyze
flutter test
```

## Notas de alcance

Quedan fuera del MVP actual:

- mensajeria/chat entre usuarios;
- pagos;
- subida de multiples fotos por anuncio;
- paginacion avanzada;
- orden avanzado;
- envio agrupado real para alertas `daily`/`weekly`;
- gestion avanzada de notificaciones en foreground o deep links desde push.

Antes de refactorizar, mantener la prioridad del proyecto: app sencilla, entendible y funcional para el TFG.
