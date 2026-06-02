# MusiHub Front Context

## Objetivo

Documento vivo del frontend de MusiHub.

Sirve para recordar contexto, decisiones y estado actual del front Flutter del TFG. Debe mantenerse practico y actualizado: si una fase ya esta cerrada, no dejar notas antiguas que contradigan el codigo.

## Forma de trabajo acordada

- Avanzar poco a poco.
- Explicar cada archivo, carpeta, comando y decision de forma pragmatica.
- No aplicar cambios grandes sin plan corto y validacion.
- Evitar scaffolding grande y arquitectura compleja si no hace falta.
- Priorizar una app real de MusiHub frente a ejemplos aislados.
- Si hace falta informacion del backend y no esta clara, pedir al usuario el dato exacto para que lo consulte en backend.
- En este contexto trabajar solo front. Si algo apunta a problema de backend, explicarlo y pedir validacion en el contexto/carpeta de backend.
- Figma es referencia visual, no una regla rigida: se adapta con sentido comun a lo que el MVP necesita.

## Producto

MusiHub es una app movil para comunidad musical.

MVP funcional:

1. identidad;
2. perfil y catalogos;
3. anuncios;
4. busqueda;
5. bandas;
6. alertas y notificaciones.

Stack:

- Flutter;
- FastAPI;
- PostgreSQL;
- JWT;
- FCM en Android para push real.

## Estado actual del frontend

La app Flutter ya esta generada con nombre interno `musihub_front`.

El frontend ya integra:

- auth real:
  - registro;
  - login;
  - sesion guardada;
  - logout;
  - desregistro del token FCM en logout;
- onboarding de registro:
  - datos de cuenta;
  - rol;
  - perfil inicial;
  - consentimiento basico;
  - alertas iniciales;
  - auto-login al terminar;
- perfil:
  - lectura/edicion de perfil propio;
  - instrumentos, instrumento principal y estilos;
  - ciudad/provincia mediante catalogo cerrado;
  - bio con limites de longitud;
  - URL personal/red social;
  - datos de contacto privados;
  - subida real de foto de perfil;
  - perfil publico sin datos privados de contacto;
  - rol visual en el perfil;
- anuncios:
  - feed publico de oportunidades activas;
  - detalle de anuncio;
  - crear/editar anuncio;
  - cerrar/reabrir anuncio propio;
  - mis anuncios;
  - publicar como usuario o como banda propia;
  - filtros por tipo, ubicacion, instrumento, estilo, fecha y precio;
  - busqueda por texto `q`;
  - compartir anuncio;
  - contacto privado mediante solicitudes;
- favoritos:
  - guardar/quitar favoritos;
  - listado de guardados;
  - anuncios cerrados aparecen atenuados en guardados;
- solicitudes de contacto:
  - crear solicitud desde detalle;
  - ver recibidas;
  - ver enviadas;
  - aceptar/rechazar recibidas;
  - abrir contacto si la solicitud fue aceptada;
  - abrir perfil publico del solicitante desde recibidas;
- bandas:
  - listar mis bandas;
  - crear banda;
  - ver detalle;
  - editar datos basicos;
  - subir foto de banda;
  - invitar miembros buscando perfiles por nombre;
  - eliminar banda si backend lo permite;
  - publicar anuncios como banda;
  - decidir visibilidad de la banda en el perfil propio;
- busqueda:
  - buscador global sencillo con secciones para anuncios, perfiles y bandas;
  - busqueda de perfiles/bandas con token;
- alertas:
  - configurar alertas;
  - activar/desactivar;
  - frecuencia fija `immediate` en UI;
  - ciudad/provincia opcional;
  - tipos de anuncio;
  - instrumentos y estilos de interes independientes del perfil musical;
  - listado de alertas generadas;
  - apertura del detalle de anuncio desde una alerta;
- push/FCM:
  - inicializacion de Firebase en Android;
  - obtencion de token FCM;
  - registro en backend con `POST /device-tokens`;
  - reenvio en `onTokenRefresh`;
  - desregistro en logout con `POST /device-tokens/unregister`;
- notificaciones in-app:
  - campana en feed;
  - panel inferior con notificaciones;
  - contador de no leidas;
  - marcar una o todas como leidas.

## Backend cloud

Base URL por defecto del front:

```text
https://musihub-back.onrender.com/api/v1
```

Estado:

- Backend desplegado en Render.
- PostgreSQL cloud en Supabase.
- Front apunta a nube por defecto desde `ApiConfig.defaultBaseUrl`.
- La primera peticion puede tardar si Render free estaba dormido.

Para probar otro backend de forma puntual, usar `--dart-define=API_BASE_URL=...`.

## Estructura actual

```text
lib/
  main.dart
  core/
    api/
      api_client.dart
    catalog/
      catalog_item.dart
      locations_api.dart
    config/
      api_config.dart
    forms/
      input_limits.dart
    push/
      device_tokens_api.dart
      push_notifications_service.dart
    session/
      token_store.dart
    theme/
      musihub_theme.dart
    uploads/
      image_upload_rules.dart
    widgets/
      contact_action_tile.dart
      location_selector.dart
      musihub_empty_state.dart
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

Decisiones:

- `core/` contiene piezas reutilizables y pequenas.
- `features/` agrupa cada bloque funcional.
- Las APIs y modelos viven cerca de su feature para que el proyecto siga siendo entendible.
- No se usa estado global complejo por ahora.
- La navegacion se mantiene con `Navigator` y `MaterialPageRoute`, suficiente para el MVP.

## Dependencias principales

- `http`: llamadas REST contra FastAPI.
- `flutter_secure_storage`: guardar JWT.
- `firebase_core` y `firebase_messaging`: FCM Android.
- `share_plus`: compartir anuncios.
- `image_picker`: seleccionar fotos de perfil/banda.
- `http_parser`: multipart/form-data para fotos.
- `url_launcher`: abrir email, telefono, WhatsApp o enlaces.

## Diseño

Referencia visual principal: Figma `Diseño MusiHub`.

Color principal:

```text
#737DFF
```

Reglas actuales:

- Usar Figma como guia de atmosfera, jerarquia, colores y espaciado.
- Adaptar si Figma no cubre una funcionalidad real.
- Mantener el codigo visual sencillo.
- No anadir librerias de diseno ni fuentes externas salvo decision explicita.

Pantallas ya adaptadas en mayor o menor medida:

- login;
- onboarding;
- feed de oportunidades;
- publicar/editar anuncio;
- detalle de anuncio;
- perfil;
- bandas;
- alertas;
- notificaciones.

## Validacion habitual

Desde `APP/MusiHub-Front`:

```bash
flutter analyze
flutter test
```

Ejecucion contra nube:

```bash
flutter run -d <ID_DISPOSITIVO>
```

APK debug contra nube:

```bash
flutter build apk --debug
```

Override manual de URL si hace falta:

```bash
flutter run -d <ID_DISPOSITIVO> --dart-define=API_BASE_URL=https://musihub-back.onrender.com/api/v1
```

## Fuera del MVP actual

- chat/mensajeria;
- pagos;
- envio agrupado real daily/weekly de alertas;
- deep link completo al tocar push;
- notificacion visual propia cuando la app esta en foreground;
- paginacion avanzada;
- orden avanzado;
- multiples fotos por anuncio;
- eliminar cuenta de usuario.

## Deuda tecnica detectada antes de subir a nube

El proyecto funciona y no necesita arquitectura nueva, pero algunas pantallas han crecido:

- `opportunity_form_screen.dart`;
- `opportunity_detail_screen.dart`;
- `alerts_screen.dart`.

Ya se extrajeron widgets visuales del perfil a:

```text
lib/features/profile/widgets/profile_widgets.dart
```

Ya se extrajeron widgets visuales del detalle de anuncio a:

```text
lib/features/opportunities/widgets/opportunity_detail_widgets.dart
```

Ya se unifico el formato de fechas de alertas, notificaciones y solicitudes en:

```text
lib/core/formatters/date_formatters.dart
```

Refactor recomendado por fases:

1. Mantener documentacion y textos al dia.
2. Revisar `opportunity_form_screen.dart` solo si vuelve a crecer o dificulta cambios.

Evitar por ahora:

- separar todos los modelos en carpetas nuevas;
- meter Riverpod/Bloc/Provider;
- reescribir navegacion;
- crear componentes genericos para todo.
