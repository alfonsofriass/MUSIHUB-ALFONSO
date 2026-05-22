---
name: finish-phase
description: Usar al cerrar una fase backend antes de preparar el commit.
---

## Goal
Revisar que la fase queda simple, mantenible y sin sobreingenieria, y preparar
los comandos de Git para que los ejecute el usuario.

## Workflow
1. Revisar el diff de la fase y comprobar que solo toca archivos relacionados.
2. Buscar si hay codigo duplicado, helpers prematuros, capas innecesarias,
   nombres confusos o reglas de negocio repartidas sin necesidad.
3. Verificar que no se ha reinventado algo ya existente en el repo.
4. Confirmar que `db-diagram.txt`, migraciones, modelos y endpoints estan
   alineados si la fase toca datos.
5. Ejecutar o proponer las validaciones relevantes:
   `python -m compileall app`, `configure_mappers`, `alembic heads` y pruebas
   HTTP/curl del flujo.
6. Revisar `git status --short` y separar cambios propios de cambios ajenos.
7. No ejecutar `git add`, `git commit` ni `git push`.
8. Mostrar al usuario los comandos exactos para stagear solo los archivos de la
   fase, commitear y pushear.

## Output
Responder con:

- `Revision`: si hay algo que simplificar o si queda correcto.
- `Validacion`: comandos ejecutados/propuestos y resultado.
- `Archivos de la fase`: lista exacta.
- `No incluir`: archivos sucios ajenos o privados.
- `Comandos`: `git add`, `git commit` y `git push` listos para que los ejecute
  el usuario.

## Constraints
- No ejecutar comandos de Git que modifiquen staging, historial o remoto.
- No incluir `MUSIHUB_PROJECT_CONTEXT.md`, `main.tex`, `.env` ni artefactos
  generados salvo peticion explicita.
- No aprovechar el cierre para refactors no relacionados.
- Si aparece un problema estructural, explicarlo y pedir validacion antes de
  tocar mas codigo.
