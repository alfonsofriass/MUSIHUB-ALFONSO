# MusiHub Front - Windows Setup

## Objetivo
Dejar el TFG funcionando en Windows con:

- Frontend Flutter.
- Backend FastAPI.
- PostgreSQL con Docker.
- Emulador Android o Chrome para pruebas rapidas.

## Herramientas necesarias
Instalar en Windows:

- Git.
- Flutter SDK.
- Android Studio.
- Docker Desktop con WSL2 activado.
- Python 3.11 o superior.
- VS Code o Antigravity.

Extensiones recomendadas en VS Code/Antigravity:

- Flutter.
- Dart.

No hacen falta para el front:

- Language Support for Java by Red Hat.
- Extension Pack for Java.
- Debugger for Java.

## Clonar el repositorio
En PowerShell:

```powershell
cd C:\Users\Alfonso\Documents
git clone https://github.com/alfonsofriass/APP-MUSICAL-TGF-ALFONSO.git
cd APP-MUSICAL-TGF-ALFONSO
```

## Comprobar Flutter
```powershell
flutter doctor
```

Debe estar correcto al menos:

```text
[✓] Flutter
[✓] Android toolchain
```

Si faltan licencias Android:

```powershell
flutter doctor --android-licenses
```

## Preparar backend en Windows
Desde la raiz del repo:

```powershell
cd APP\MusiHub-Back
py -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

Crear un archivo local `.env` en `APP\MusiHub-Back`.

No subir `.env` a Git. Debe contener las mismas variables que el backend espera:

```env
APP_NAME=MusiHub API
SECRET_KEY=pon_aqui_una_clave_local_de_desarrollo
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
DATABASE_URL=postgresql+psycopg://musihub:musihub_dev_password@localhost:5432/musihub
```

Levantar PostgreSQL:

```powershell
docker compose up -d
```

Aplicar migraciones:

```powershell
alembic upgrade head
```

Arrancar FastAPI:

```powershell
uvicorn app.main:app --reload
```

La API deberia quedar en:

```text
http://127.0.0.1:8000/api/v1
```

## Preparar frontend en Windows
En otra terminal:

```powershell
cd APP\MusiHub-Front
flutter pub get
flutter analyze
flutter test
```

## Ejecutar en emulador Android
Arrancar un emulador desde Android Studio y despues:

```powershell
flutter devices
flutter run
```

En Android se usa por defecto:

```text
http://10.0.2.2:8000/api/v1
```

Motivo: desde el emulador, `127.0.0.1` apunta al propio emulador, no al PC.

## Ejecutar en Chrome
Si el soporte web existe en el proyecto:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Chrome usa `127.0.0.1` porque corre en el propio Windows.

## Estado funcional esperado
El primer objetivo del front es validar:

```text
Login Flutter -> POST /auth/login -> guardar token -> GET /auth/me -> Home
```

No se debe implementar todavia:

- perfiles,
- catalogos,
- anuncios,
- busqueda,
- favoritos,
- bandas,
- alertas,
- FCM,
- diseno final.
