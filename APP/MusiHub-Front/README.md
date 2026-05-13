# MusiHub Front

Frontend móvil de MusiHub, app desarrollada en Flutter para el TFG.

## Estado actual
- La app Flutter ya está generada con nombre interno `musihub_front`.
- Auth real conectado contra FastAPI:
  - registro,
  - login,
  - validación de sesión con `/auth/me`.
- Perfil musical mínimo conectado:
  - carga de catálogos,
  - lectura de perfil,
  - creación/edición de perfil.
- Anuncios mínimos conectados:
  - listado público,
  - detalle,
  - mis anuncios,
  - creación,
  - edición,
  - cierre.
- El diseño final queda pendiente porque se replicará desde Figma más adelante.

## Documentación local
- `MUSIHUB_FRONT_CONTEXT.md`: contexto vivo específico del frontend.
- `WINDOWS_SETUP.md`: pasos para preparar el TFG en Windows.
- `CODEX_WINDOWS_FRONT_PROMPT.md`: prompt listo para continuar en Codex desde Windows.
- `main.tex`: memoria del TFG.
- `db-diagram.txt`: referencia del esquema de base de datos general del proyecto.

## Alcance inmediato
- Mantener la app simple y entendible.
- Consolidar el flujo actual antes de pasar al siguiente bloque funcional.
- Preparar búsqueda/filtros como siguiente fase cuando backend esté listo.

Quedan fuera por ahora búsqueda/filtros avanzados, favoritos, bandas, alertas, FCM y diseño final.

## Comandos útiles
Desde `APP/MusiHub-Front`:

```bash
flutter pub get
flutter analyze
flutter test
```

Para ejecutar en Chrome contra backend local:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Para ejecutar en emulador Android contra backend local:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```
