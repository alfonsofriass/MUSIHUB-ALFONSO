# MusiHub Front

Aplicacion movil de MusiHub desarrollada con Flutter para el Trabajo Fin de Grado.

MusiHub es una app orientada a la comunidad musical. Permite crear un perfil musical, publicar oportunidades, buscar anuncios, gestionar bandas, guardar favoritos, solicitar contacto y recibir alertas personalizadas.

## Funcionalidades principales

- Registro, inicio de sesion y sesion guardada.
- Onboarding inicial de usuario.
- Perfil musical editable y perfil publico.
- Publicacion, edicion, cierre y reapertura de anuncios.
- Feed de oportunidades con busqueda y filtros.
- Favoritos/guardados.
- Solicitudes privadas de contacto.
- Gestion de bandas.
- Alertas configurables y notificaciones.
- Subida de fotos de perfil y banda.
- Compartir anuncios y abrir metodos de contacto.

## Estructura

```text
lib/
  main.dart
  core/       Codigo compartido: API, sesion, tema, catalogos y widgets comunes.
  features/   Funcionalidades principales: auth, perfil, anuncios, bandas, alertas, etc.
```

## Backend

La app apunta por defecto al backend desplegado:

```text
https://musihub-back.onrender.com/api/v1
```

Tambien se puede sobrescribir la URL con `API_BASE_URL`:

```bash
flutter run -d <ID_DISPOSITIVO> --dart-define=API_BASE_URL=<URL_BACKEND>
```

## Comandos utiles

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d <ID_DISPOSITIVO>
flutter build apk --debug
```
