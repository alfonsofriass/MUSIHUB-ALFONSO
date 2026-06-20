# MusiHub - Trabajo Fin de Grado

Este repositorio contiene el desarrollo completo del Trabajo Fin de Grado **MusiHub**, una aplicación móvil orientada a la comunidad musical. El proyecto ha sido realizado en el marco del **Grado en Ingeniería Informática de la Universidad de Granada**.

MusiHub tiene como objetivo centralizar oportunidades musicales entre músicos, bandas y entidades, permitiendo crear perfiles, publicar anuncios, buscar oportunidades mediante filtros, gestionar bandas, solicitar contacto y recibir alertas personalizadas.

## Organización del repositorio

```text
TFG/
├── APP/
│   ├── MusiHub-Back/       # Backend/API del proyecto
│   └── MusiHub-Front/      # Aplicación móvil Flutter
├── Docu/
│   ├── Docu/               # Memoria del TFG en LaTeX y recursos asociados
│   ├── SPRINT */           # Documentación de seguimiento por sprint
│   └── ...                 # Capturas, referencias y material de apoyo
├── firebase/               # Archivos relacionados con Firebase
├── Icons Desing/           # Recursos visuales e iconos de diseño
└── TFGS/                   # TFGs de referencia consultados
```

## Carpetas principales

### `APP/MusiHub-Back`

Contiene el backend de MusiHub, desarrollado con **FastAPI**. Incluye la lógica de negocio, autenticación, gestión de usuarios, perfiles, anuncios, bandas, solicitudes de contacto, alertas y conexión con la base de datos.

### `APP/MusiHub-Front`

Contiene la aplicación móvil desarrollada con **Flutter**. Desde esta app el usuario puede registrarse, completar su perfil musical, consultar oportunidades, publicar anuncios, gestionar bandas, solicitar contacto y recibir alertas/notificaciones.

### `Docu/Docu`

Contiene la memoria principal del TFG en **LaTeX**, junto con capturas, diagramas, anexos, bibliografía y recursos utilizados para generar el documento final.

### `Docu/SPRINT *`

Contiene la documentación de seguimiento del proyecto por sprints: objetivos, trabajo realizado, puntos tratados en reuniones y planificación del sprint siguiente.

### `TFGS`

Incluye trabajos de referencia utilizados para orientar la estructura, nivel de detalle y estilo de la memoria.

## Tecnologías principales

- **Flutter** para el cliente móvil.
- **FastAPI** para el backend/API.
- **PostgreSQL** como base de datos principal.
- **Firebase Cloud Messaging** para notificaciones push.
- **Docker** para apoyo al entorno local de desarrollo.
- **LaTeX** para la elaboración de la memoria.

## Estado del proyecto

El repositorio recoge tanto la implementación de la aplicación como la documentación académica asociada al TFG. La memoria final se encuentra en `Docu/Docu/main.pdf` y el código fuente principal se organiza dentro de `APP/`.
