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
  - pantalla de perfil en modo lectura,
  - creación/edición de perfil,
  - cierre de sesión desde perfil.
- Anuncios mínimos conectados:
  - listado público,
  - detalle visual adaptado parcialmente,
  - mis anuncios,
  - creación,
  - edición,
  - cierre.
- Filtros mínimos en listado público de anuncios:
  - tipo,
  - ciudad,
  - provincia,
  - instrumento,
  - estilo,
  - fecha,
  - precio.
- Primer bloque visual desde Figma iniciado:
  - tema global de MusiHub,
  - pantalla de publicar/editar anuncio adaptada parcialmente.
- Color principal de marca: lila/azul suave `#737DFF`, tomado del filtro activo del feed.
- Feed/listado de anuncios adaptado parcialmente:
  - cards de anuncio,
  - chips,
  - buscador visual,
  - bottom navigation.
- Detalle de anuncio adaptado parcialmente:
  - fecha sin hora,
  - autor provisional `Usuario #id`,
  - contacto/favorito/compartir pintados sin funcionalidad real.
- El feed es la entrada principal tras login o sesion guardada.
- Desde Perfil se puede abrir `Mis anuncios` y cerrar sesion.
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
- Preparar el siguiente bloque funcional cuando backend esté listo.

Quedan fuera por ahora favoritos, bandas, alertas, FCM, paginación, búsqueda por texto libre, orden avanzado y diseño final.

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
