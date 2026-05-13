# Prompt exacto para Codex en Windows - MusiHub Front

Copia y pega este prompt en un nuevo chat de Codex si algun dia se continua el frontend desde Windows.

```text
Estamos trabajando en MusiHub, app movil Flutter para un TFG.

Contexto de repo:
- Repo: APP-MUSICAL-TGF-ALFONSO.
- Front: APP/MusiHub-Front.
- Back: APP/MusiHub-Back.
- Stack: Flutter + FastAPI + PostgreSQL.
- FCM queda para mas adelante, no ahora.

Antes de hacer nada, lee:
- APP/MusiHub-Front/MUSIHUB_FRONT_CONTEXT.md
- APP/MusiHub-Front/README.md
- APP/MusiHub-Front/WINDOWS_SETUP.md
- APP/MusiHub-Front/main.tex si existe
- APP/MusiHub-Front/db-diagram.txt si existe

Forma de trabajar:
- No aplicar cambios de codigo directamente por defecto.
- Primero propuesta breve -> revision del usuario -> aplicar solo si el usuario lo pide.
- Avanzar en pasos pequenos.
- No meter scaffolding grande.
- Explicar pragmaticamente que se hace y por que, ligado a MusiHub.
- Objetivo de aprendizaje: quiero entender cada archivo, carpeta, comando y decision.
- Antes de cambios grandes, plan corto y validacion.
- Si necesitas informacion del backend que no este clara, pideme exactamente el dato necesario y te lo paso desde el back.
- Este chat debe limitarse a trabajo del frontend. Si un problema apunta a backend, explicalo y pide validarlo en el chat/carpeta del backend.

Contexto funcional:
MusiHub es una app movil para comunidad musical.

MVP:
- auth
- perfil
- anuncios
- busqueda/filtros
- favoritos
- bandas
- alertas

Orden funcional validado:
1. identidad
2. perfil/catalogos
3. anuncios
4. busqueda
5. bandas
6. alertas

Backend local:
- Windows/Chrome/escritorio: http://127.0.0.1:8000/api/v1
- Emulador Android: http://10.0.2.2:8000/api/v1

Estado actual del front:
- Proyecto Flutter creado con nombre interno musihub_front.
- Dependencias principales:
  - http
  - flutter_secure_storage
- Auth real conectado:
  - POST /auth/register
  - POST /auth/login
  - GET /auth/me
- Token guardado con flutter_secure_storage.
- SessionGate valida token guardado al arrancar.
- Perfil/catalogos conectado:
  - GET /catalogs/instruments
  - GET /catalogs/music-styles
  - GET /profile/me
  - PUT /profile/me
- Anuncios conectado:
  - GET /catalogs/opportunity-types
  - GET /opportunities
  - GET /opportunities/{id}
  - GET /opportunities/me
  - POST /opportunities
  - PATCH /opportunities/{id}
  - PATCH /opportunities/{id}/close
- Las pantallas son minimas y funcionales; el diseno final se replicara desde Figma mas adelante.
- Los mensajes de error se mantienen genericos por ahora.

Validacion hecha:
- flutter analyze: sin problemas.
- flutter test: correcto.

Objetivo inmediato:
- Cerrar commit limpio del frontend actual.
- No meter cambios de backend ni de raiz del repo en el commit del front.
- Siguiente fase funcional probable: busqueda/filtros cuando backend este listo.

Comandos utiles en Windows desde APP/MusiHub-Front:

flutter pub get
flutter analyze
flutter test

Para Chrome:

flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1

Para emulador Android:

flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

No implementar todavia:
- FCM
- bandas
- alertas
- favoritos
- diseno final de Figma
- arquitectura compleja de golpe
```
