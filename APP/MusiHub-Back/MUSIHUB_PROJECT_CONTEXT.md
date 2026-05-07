# MusiHub Project Context

## Objetivo
Documento vivo para mantener el contexto funcional y técnico del proyecto mientras se implementa la app del TFG.

## Estado actual
- El proyecto arranca desde cero.
- La documentación funcional y técnica de referencia está en `Docu/main.tex`.
- La carpeta de implementación `Proyecto` cuelga ahora del directorio actual de trabajo para simplificar la navegación.
- El esquema de base de datos de referencia es `Proyecto/db-diagram.txt`.
- El backend se ha reducido intencionadamente a una base mínima para aprender `FastAPI` paso a paso.
- Este archivo debe actualizarse cuando se cierre una decisión relevante o cambie el alcance.

## Visión del producto
MusiHub es una app móvil orientada a la comunidad musical para centralizar oportunidades y perfiles en un único espacio.

El valor principal del producto es combinar:
- perfiles musicales estructurados,
- publicaciones tipificadas,
- búsqueda con filtros,
- alertas personalizadas con lógica explicable.

## MVP acordado
- Registro e inicio de sesión.
- Perfil por rol.
- Publicación y gestión de anuncios.
- Consulta, búsqueda y filtrado.
- Preferencias de alertas.
- Alertas personalizadas y notificaciones.
- Favoritos.
- Contacto externo desde el anuncio.
- Gestión básica de bandas.
- Publicación de anuncios como banda.

## Roles del sistema
- `musico`
- `venta`
- `sala_bar`
- `academia_profesor`

## Bandas
- Una banda no es un usuario autenticable independiente.
- La banda es una entidad creada y gestionada por músicos.
- Debe funcionar como un perfil colectivo con información propia y miembros asociados.
- Un músico administrador podrá crear y gestionar la banda.

## Tipos de oportunidad del MVP
- clases
- bolos o sustituciones
- búsqueda de miembros
- eventos
- compraventa

## Stack acordado
- Frontend móvil: `Flutter`
- Backend API: `FastAPI`
- Base de datos: `PostgreSQL`
- Modelo de datos: relacional normalizado
- Notificaciones push: `Firebase Cloud Messaging (FCM)`
- Autenticación inicial: email/password + JWT

## Principios de implementación
- Priorizar la solución más sencilla, mantenible y suficiente para el MVP.
- No introducir sobreingeniería.
- No inventar complejidad futura si no resuelve una necesidad actual.
- No reinventar la rueda si existe una solución estándar y razonable.
- Mantener una separación clara entre decisiones de producto, arquitectura e implementación.

## Reglas de trabajo acordadas
- Antes de tomar decisiones grandes, analizar primero el contexto total del proyecto.
- Antes de escribir grandes cantidades de código, preparar un plan.
- El plan debe pasar por validación del usuario antes de ejecutarse.
- No crear scaffolding grande ni muchos archivos de golpe sin validación intermedia del usuario.
- Avanzar en pasos pequeños y revisables, idealmente archivo a archivo o en bloques muy cortos y justificados.
- Antes de crear nuevos archivos o tocar una zona amplia, explicar qué se va a hacer y esperar validación si el cambio es estructural.
- No aplicar cambios de código directamente por defecto. Primero mostrar el contenido propuesto o el bloque exacto a cambiar.
- El flujo preferido es `propuesta -> revisión del usuario -> copia manual por el usuario` salvo que el usuario pida expresamente que se aplique.
- Evitar forzar iteraciones de depuración por cambios ya escritos: priorizar que el usuario vea el archivo o fragmento completo antes de tocarlo.
- Objetivo de aprendizaje: explicar qué es cada archivo, carpeta, comando y decisión técnica antes o justo después de usarlo.
- No introducir una nueva capa técnica hasta haber entendido para qué sirve la anterior.
- El aprendizaje debe ir ligado al montaje real del proyecto: priorizar pasos que construyan `MusiHub` de verdad frente a ejemplos aislados o demasiado académicos.
- Mantener explicaciones pragmáticas y cortas, centradas en por qué se hace algo en este proyecto, no en convertir cada cambio en una clase teórica.
- En cualquier decisión de modelo de datos, manda `Proyecto/db-diagram.txt`.
- Si el código existente entra en conflicto con `Proyecto/db-diagram.txt`, debe corregirse el código, no reinterpretarse el diagrama por comodidad.
- Cuando una decisión quede cerrada, registrarla en este archivo.
- Si aparece una duda estructural importante, detener la implementación y validarla primero.

## Supuestos cerrados a día de hoy
- El proyecto se implementará desde cero.
- El frontend móvil se implementará en Flutter.
- El modelo de datos base será relacional normalizado.
- El esquema de base de datos seguirá de forma estricta `Proyecto/db-diagram.txt`.
- Aunque el diagrama soporta `roles` y `user_roles`, el flujo inicial de registro seguirá asignando un único rol primario por usuario.
- El backend será responsable del `matching`, reglas de alertas y trazabilidad.
- La primera autenticación será únicamente con email/password.
- La banda no tendrá login propio.
- `users` no tendrá campo `status` en el MVP; se evita añadir gestión de bloqueo/pendiente si no resuelve una necesidad actual.

## Dudas abiertas pendientes
- Concretar cómo se ejecutarán las alertas no inmediatas.

## Próximo paso obligatorio
Cerrar la validación de Fase 1 con autenticación real ya probada y pasar después al siguiente bloque funcional: perfil/catálogos.

## Estado de implementación
- El proyecto mantiene `Proyecto/db-diagram.txt` como referencia del esquema.
- El backend mantiene una base pequeña de `FastAPI`, pero ya tiene persistencia real con `PostgreSQL`, `SQLAlchemy` y `Alembic`.
- La API ya arranca con un router versionado en `/api/v1`.
- Las rutas iniciales de sistema quedan agrupadas en un módulo pequeño y real: `health` y `roles`.
- La Fase 1 está muy avanzada: Docker/PostgreSQL, configuración, modelos iniciales, migraciones y autenticación `email/password + JWT` están montados.
- Tablas reales actuales de autenticación: `users`, `roles`, `user_roles`.
- Roles base insertados: `musico`, `venta`, `sala_bar`, `academia_profesor`.
- `POST /api/v1/auth/register` ya registra usuario real, hashea password y crea `user_roles.is_primary=True`.
- `POST /api/v1/auth/login` ya valida email/password contra BD y genera JWT con `sub = user.id`.
- `GET /api/v1/auth/me` ya valida JWT, carga usuario desde BD y devuelve `id`, `email`, `full_name` y rol principal.
- Flujo probado por HTTP: `register -> login -> me`.
- Migración actual aplicada: `8c92cf6527c0_drop_user_status.py`, que elimina `users.status` para alinear el código con `db-diagram.txt`.
- Queda como siguiente cierre práctico de Fase 1 actualizar/verificar dependencias si reaparece el aviso de `passlib/bcrypt`; funcionalmente el hash ya devuelve `True` para contraseña correcta y `False` para incorrecta.

## Planning inicial aprobado
1. Fase 0. Cierre de base funcional y técnica.
   - Definir el modelo de datos final.
   - Definir los campos obligatorios por tipo de anuncio.
   - Definir permisos mínimos.
   - Definir la estructura inicial del repositorio.
   - Validar en papel tres flujos: `registro -> perfil -> publicar anuncio`, `buscar -> filtrar -> contactar`, `crear banda -> publicar como banda`.
2. Fase 1. Base del backend.
   - Montar `FastAPI`, `PostgreSQL`, migraciones, configuración local con Docker y autenticación `email/password + JWT`.
3. Fase 2. Base de la app Flutter.
   - Crear la app móvil, navegación inicial, gestión de sesión y cliente API.
4. Fase 3. Catálogos y perfiles.
   - Implementar roles, perfil de usuario, instrumentos, estilos y campos básicos por actor.
5. Fase 4. Anuncios V1.
   - Implementar crear, editar, cerrar, listar y ver detalle de oportunidades para usuario individual.
6. Fase 5. Búsqueda, filtros y favoritos.
   - Implementar filtros combinados y favoritos.
7. Fase 6. Bandas.
   - Implementar entidad banda, membresías y publicación como banda.
8. Fase 7. Alertas V1 sin push real.
   - Implementar preferencias, `matching`, umbral, trazabilidad y anti-duplicados guardando alertas en base de datos.
9. Fase 8. Push y frecuencias programadas.
   - Integrar `FCM` y después el script para envíos `daily/weekly`.

## Orden de prioridad real
- Primero: autenticación, perfil, anuncios y búsqueda.
- Después: favoritos y bandas.
- Al final: alertas, trazabilidad y notificaciones push.

## Restricciones de alcance inicial
- No implementar chat interno al principio.
- No introducir recomendación con IA o aprendizaje automático.
- No crear arquitecturas complejas con colas o microservicios.
- No añadir permisos finos si una regla simple de autor/admin es suficiente.

## Fase 0 validada
Esta sección recoge la base funcional y técnica validada antes de la implementación.

### Orden funcional de construcción
- Primero identidad: usuario, autenticación y sesión.
- Después perfil y catálogos: roles, instrumentos y estilos.
- Después contenido: anuncios y detalle.
- Después descubrimiento: búsqueda, filtros y favoritos.
- Después entidades colectivas: bandas.
- Al final automatización: preferencias, `matching` y notificaciones.

### Dependencias reales del sistema
- No hay publicación sin autenticación.
- No hay filtros útiles sin catálogos y campos normalizados.
- No hay alertas sin anuncios, perfiles y preferencias.
- No hay publicación como banda sin modelo de banda y permisos mínimos.

### Estructura inicial propuesta del repositorio
- `Proyecto/front`: app Flutter.
- `Proyecto/back`: API FastAPI.
- `Proyecto/MUSIHUB_PROJECT_CONTEXT.md`: contexto y decisiones.
- `Proyecto/db-diagram.txt`: referencia del esquema de base de datos.
- En raíz del proyecto, más adelante, se reintroducirán otros archivos de infraestructura si hacen falta.

### Estructura inicial propuesta del backend
- `back/app/main.py`
- `back/requirements.txt`

### Estructura inicial propuesta del frontend
- `front/lib/app`
- `front/lib/core`
- `front/lib/features`
- `front/test`

### Propuesta funcional de acceso
- La app requiere autenticación para usar las funcionalidades del MVP.
- Solo quedan fuera de autenticación: registro e inicio de sesión.

### Propuesta de permisos mínimos
- Usuario autenticado:
  - ver y editar su propio perfil,
  - gestionar sus preferencias,
  - gestionar sus favoritos,
  - crear anuncios propios,
  - editar y cerrar solo sus anuncios.
- Banda:
  - el creador de la banda pasa a ser administrador,
  - el administrador puede editar la banda,
  - el administrador puede gestionar miembros,
  - el administrador puede publicar, editar y cerrar anuncios de la banda.
- Miembro de banda no administrador:
  - puede figurar en la banda,
  - no puede modificar la banda ni publicar en su nombre.

### Propuesta de simplificación para roles
- Para el MVP, cada cuenta tendrá un rol principal.
- Si más adelante hace falta multirrol real, se ampliará sobre una base simple ya validada.

### Entidades funcionales base
- `users`
- `roles`
- `user_roles`
- `profiles`
- `instruments`
- `music_styles`
- `bands`
- `band_members`
- `opportunity_types`
- `opportunities`
- `opportunity_instruments`
- `opportunity_styles`
- `favorites`
- `alert_preferences`
- `alert_preference_types`

### Propuesta de campos comunes obligatorios en un anuncio
- `type`
- `title`
- `description`
- `city`
- `contact_method`
- `contact_value`

### Propuesta de campos obligatorios por tipo de anuncio
- `clases`:
  - comunes obligatorios.
- `bolos_sustituciones`:
  - comunes obligatorios,
  - `event_date`,
  - al menos un instrumento asociado.
- `busqueda_miembros`:
  - comunes obligatorios,
  - al menos un instrumento asociado.
- `eventos`:
  - comunes obligatorios,
  - `event_date`.
- `compraventa`:
  - comunes obligatorios,
  - `price_amount`.

### Flujos de validación de fase 0
- `registro -> perfil -> publicar anuncio`
- `buscar -> filtrar -> contactar`
- `crear banda -> publicar como banda`

## Contexto para migración a Windows y handoff Frontend

### Estado actual antes de migrar
- Backend FastAPI de MusiHub validado en Fase 1.
- Autenticación real funcionando contra PostgreSQL:
  - `POST /api/v1/auth/register`
  - `POST /api/v1/auth/login`
  - `GET /api/v1/auth/me`
- Flujo probado: `register -> login -> me`.
- Alembic head esperado: `8c92cf6527c0`.
- La base actual de autenticación contiene:
  - `users`
  - `roles`
  - `user_roles`
- Roles válidos actuales:
  - `musico`
  - `venta`
  - `sala_bar`
  - `academia_profesor`
- En el MVP cada cuenta mantiene un único rol principal.
- La banda no tiene login propio.
- `users` no tiene campo `status`.
- Siguiente bloque recomendado: cerrar una Fase 2 Flutter mínima conectada al backend.
- Después de Flutter auth mínima, volver al backend con perfil/catálogos:
  - `profiles`
  - `instruments`
  - `music_styles`
  - `profile_instruments`
  - `profile_styles`

### Prompt para Codex Frontend en Windows
Estamos trabajando en MusiHub, app móvil Flutter para un TFG.

Antes de hacer nada, lee:
- `MUSIHUB_PROJECT_CONTEXT.md`
- `main.tex`
- `db-diagram.txt`
- `README.md` si existe

Forma de trabajar:
- No aplicar cambios directamente por defecto.
- Primero propuesta breve -> revisión del usuario -> aplicar solo si el usuario lo pide.
- Avanzar en pasos pequeños.
- No meter scaffolding grande.
- Explicar qué se hace y por qué, ligado a MusiHub.
- Objetivo de aprendizaje: entender cada archivo, carpeta, comando y decisión.
- En decisiones de datos manda `db-diagram.txt`.
- Si el código contradice `db-diagram.txt`, se corrige el código.

Contexto funcional:
- MusiHub es una app móvil para comunidad musical.
- MVP:
  - auth
  - perfil
  - anuncios
  - búsqueda/filtros
  - favoritos
  - bandas
  - alertas
- Orden funcional validado:
  1. identidad
  2. perfil/catálogos
  3. anuncios
  4. búsqueda
  5. bandas
  6. alertas

Backend actual:
- FastAPI ya tiene auth real funcionando.
- Base URL local desde Windows, escritorio o web:
  - `http://127.0.0.1:8000/api/v1`
- Base URL desde emulador Android:
  - `http://10.0.2.2:8000/api/v1`

Endpoints actuales:
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`

Contrato actual de auth:

`POST /api/v1/auth/register`

Payload:
```json
{
  "email": "test@example.org",
  "password": "password123",
  "full_name": "Usuario Test",
  "role": "musico"
}
```

Roles válidos:
- `musico`
- `venta`
- `sala_bar`
- `academia_profesor`

`POST /api/v1/auth/login`

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

`GET /api/v1/auth/me`

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

Objetivo inmediato del frontend:
- Crear una Fase 2 Flutter mínima para validar:
  - `Flutter -> FastAPI -> PostgreSQL`

Alcance:
- Login mínimo.
- Registro mínimo.
- Home/sesión mínima llamando a `/auth/me`.
- Cliente HTTP simple.
- Guardado sencillo del token.
- No implementar perfiles, catálogos, anuncios, FCM ni diseño final todavía.
- No crear arquitectura compleja de golpe.

Primero propón:
1. Estructura mínima de carpetas Flutter.
2. Dependencias mínimas.
3. Primer paso pequeño para validar conexión con backend.
4. Comandos que debe ejecutar el usuario.
5. Archivos que tocarías, sin aplicarlo todavía.

### Pasos para preparar Windows

Backend:
1. Instalar Git.
2. Instalar Python 3.11 o 3.12.
3. Instalar Docker Desktop.
4. Clonar o copiar el repo completo.
5. Entrar en `MusiHub-Back`.
6. Crear `.venv` nuevo:
   ```powershell
   python -m venv .venv
   ```
7. Activar entorno:
   ```powershell
   .venv\Scripts\Activate.ps1
   ```
8. Instalar dependencias:
   ```powershell
   pip install -r requirements.txt
   ```
9. Crear `.env` local, sin subirlo a git:
   ```env
   APP_NAME=MusiHub API
   SECRET_KEY=poner_una_clave_local_segura
   JWT_ALGORITHM=HS256
   ACCESS_TOKEN_EXPIRE_MINUTES=60
   DATABASE_URL=postgresql+psycopg://musihub:musihub_dev_password@localhost:5432/musihub
   ```
10. Levantar PostgreSQL:
   ```powershell
   docker compose up -d db
   ```
11. Aplicar migraciones:
   ```powershell
   alembic upgrade head
   ```
12. Comprobar revisión actual:
   ```powershell
   alembic current
   ```
   Resultado esperado:
   ```text
   8c92cf6527c0 (head)
   ```
13. Arrancar API:
   ```powershell
   uvicorn app.main:app --reload
   ```
14. Probar health:
   ```powershell
   curl http://127.0.0.1:8000/api/v1/health
   ```

Frontend:
1. Instalar Flutter SDK.
2. Ejecutar:
   ```powershell
   flutter doctor
   ```
3. Abrir `MusiHub-Front`.
4. Usar `http://127.0.0.1:8000/api/v1` si se prueba en escritorio o web.
5. Usar `http://10.0.2.2:8000/api/v1` si se prueba en emulador Android.

No subir a git:
- `.env`
- `.venv/`
- `.dart_tool/`
- `build/`
- archivos temporales del IDE
