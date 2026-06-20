# MusiHub - Trabajo Fin de Grado

Repositorio del Trabajo Fin de Grado **MusiHub**, desarrollado por **Alfonso Frías Funes** en el marco del **Grado en Ingeniería Informática de la Universidad de Granada**.

MusiHub es una aplicación móvil orientada a la comunidad musical. Su objetivo es centralizar oportunidades entre músicos, bandas y entidades, permitiendo gestionar perfiles, publicar anuncios, buscar mediante filtros, crear bandas, solicitar contacto y recibir alertas personalizadas.

Repositorio público:

```text
https://github.com/alfonsofriass/MUSIHUB-ALFONSO
```

## Organización del repositorio

```text
MUSIHUB-ALFONSO/
├── APP/
│   ├── MusiHub-Back/       # Backend/API del proyecto
│   └── MusiHub-Front/      # Aplicación móvil Flutter
├── Docu/                   # Documentación del TFG y seguimiento por sprints
└── README.md
```

## Estructura principal

### `APP/MusiHub-Back`

Contiene el backend de MusiHub, desarrollado con **FastAPI**. Incluye la API, la lógica de negocio, autenticación, gestión de usuarios, perfiles, anuncios, bandas, solicitudes de contacto, alertas y conexión con la base de datos.

### `APP/MusiHub-Front`

Contiene la aplicación móvil desarrollada con **Flutter**. Desde la app se realizan los flujos principales del sistema: registro, inicio de sesión, perfil musical, consulta y publicación de oportunidades, filtros, favoritos, bandas, contacto y alertas.

### `Docu/`

Contiene la documentación académica del TFG. Dentro de esta carpeta se guardan los documentos de seguimiento por sprint y la versión final de la memoria/documentación del proyecto.

## Tecnologías principales

- **Flutter** para el cliente móvil.
- **FastAPI** para el backend/API.
- **PostgreSQL** como base de datos.
- **Firebase Cloud Messaging** para notificaciones push.
- **Docker** como apoyo al entorno local.
- **LaTeX** para la memoria del TFG.

## Documentación de sprints

El proyecto se ha desarrollado mediante iteraciones de trabajo. La carpeta `Docu/` recoge la documentación asociada a los sprints: objetivos, puntos tratados en reuniones, trabajo realizado y objetivos del siguiente sprint.

