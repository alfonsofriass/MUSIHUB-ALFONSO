---
name: plan-feature
description: Usar al iniciar una nueva fase o funcionalidad del backend MusiHub antes de escribir codigo.
---

## Goal
Definir un alcance pequeno, entendible y alineado con el MVP antes de tocar el
backend.

## Workflow
1. Leer `AGENTS.md`, `README.md`, `MUSIHUB_PROJECT_CONTEXT.md`, `db-diagram.txt`
   y `main.tex` si la feature toca funcionalidad o datos.
2. Inspeccionar el codigo existente que se pueda reutilizar.
3. Separar lo ya implementado de lo que falta.
4. Proponer el micro-alcance minimo de la siguiente entrega.
5. Indicar archivos probables, endpoints/modelos afectados y pruebas manuales.
6. Esperar validacion del usuario si el cambio es estructural o amplio.

## Output
Responder con:

- `Estado actual`: que hay ya implementado.
- `Alcance minimo`: que se propone hacer ahora y que queda fuera.
- `Plan`: pasos pequenos en orden.
- `Archivos probables`: rutas concretas.
- `Validacion`: comandos o pruebas manuales.
- `Dudas pendientes`: solo las que bloqueen una decision.

## Constraints
- No crear scaffolding grande.
- No anadir dependencias.
- Si hay datos, manda `db-diagram.txt`.
- No mezclar varias fases funcionales en el mismo cambio.
