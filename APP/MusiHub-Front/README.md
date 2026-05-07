# MusiHub Front

Frontend móvil de MusiHub, app desarrollada en Flutter para el TFG.

## Estado actual
- La app Flutter ya está generada con nombre interno `musihub_front`.
- El backend FastAPI ya tiene autenticación real funcionando.
- La pantalla mínima de login ya llama a `/auth/login` y después a `/auth/me`.
- El diseño final queda pendiente porque se replicará desde Figma más adelante.

## Documentación local
- `MUSIHUB_FRONT_CONTEXT.md`: contexto vivo específico del frontend.
- `WINDOWS_SETUP.md`: pasos para preparar el TFG en Windows.
- `CODEX_WINDOWS_FRONT_PROMPT.md`: prompt listo para continuar en Codex desde Windows.
- `main.tex`: memoria del TFG.
- `db-diagram.txt`: referencia del esquema de base de datos general del proyecto.

## Alcance inmediato
- Validar en entorno real el flujo `login -> token -> /auth/me -> home`.
- Mantener la pantalla simple hasta replicar los diseños de Figma.

Quedan fuera por ahora perfiles, catálogos, anuncios, búsqueda, favoritos, bandas, alertas, FCM y diseño final.
