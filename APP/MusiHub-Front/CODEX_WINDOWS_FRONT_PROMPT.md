# Prompt exacto para Codex en Windows - MusiHub Front

Copia y pega este prompt en el nuevo chat de Codex en Windows.

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

Estado backend:
El backend FastAPI ya tiene auth real funcionando:
- POST /api/v1/auth/register
- POST /api/v1/auth/login
- GET /api/v1/auth/me

Backend local:
- Windows/Chrome/escritorio: http://127.0.0.1:8000/api/v1
- Emulador Android: http://10.0.2.2:8000/api/v1

Contrato actual de auth:

POST /api/v1/auth/login
Payload:
{
  "email": "test@example.org",
  "password": "password123"
}

Respuesta:
{
  "access_token": "...",
  "token_type": "bearer"
}

GET /api/v1/auth/me
Header:
Authorization: Bearer <TOKEN>

Respuesta:
{
  "id": 5,
  "email": "test1@example.org",
  "full_name": "Usuario Test",
  "role": "musico"
}

Estado actual del front:
- Proyecto Flutter creado con nombre interno musihub_front.
- Dependencias anadidas:
  - http
  - flutter_secure_storage
- Archivos propios creados:
  - lib/core/config/api_config.dart
  - lib/core/api/api_client.dart
  - lib/core/session/token_store.dart
  - lib/features/auth/auth_api.dart
  - lib/features/auth/login_screen.dart
  - lib/features/home/home_screen.dart
- La app contador inicial de Flutter ya fue sustituida.
- Hay una pantalla login minima sin diseno final.
- Hay una home minima que muestra datos de /auth/me.
- Las pantallas definitivas existen en Figma y se replicaran mas adelante.

Validacion hecha antes de migrar:
- flutter analyze: sin problemas.
- flutter test: correcto.

Objetivo inmediato:
Validar en Windows el flujo real:
Login Flutter -> POST /auth/login -> guardar token -> GET /auth/me -> Home.

Siguiente paso recomendado:
1. Verificar entorno con flutter doctor.
2. Levantar backend FastAPI y PostgreSQL.
3. En APP/MusiHub-Front ejecutar flutter pub get.
4. Ejecutar flutter analyze y flutter test.
5. Probar la app en emulador Android con flutter run.
6. Si se prueba en Chrome, usar:
   flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1

No implementar todavia:
- registro visual final,
- perfiles,
- catalogos,
- anuncios,
- busqueda,
- favoritos,
- bandas,
- alertas,
- FCM,
- diseno Figma.
```
