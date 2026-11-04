# SGD · Sistema de Gestión Documental — Módulo Archivo Central

Módulo de **Archivo Central** de la Universidad Autónoma del Cauca (Uniautónoma), construido como práctica profesional. Reemplaza los Excel por año, los PDF mensuales por oficina y el circuito manual de correos por un sistema único que **registra, custodia y consulta** lo que llega al Archivo Central. Funciona **dentro de NOVA**, el portal institucional: el usuario entra con su cuenta de NOVA y el módulo aparece en su Panel de Área.

**Esta rama (`main`) trae solo lo que se despliega:** backend, base de datos y configuración de despliegue. Despliegue en producción: **[README_DEPLOY.md](README_DEPLOY.md)**.

Fuera de `main`:

- **Frontend:** repositorio [DavidM3-M/NOVA_FT](https://github.com/DavidM3-M/NOVA_FT), rama `desarrollo-archivo-central`.
- **Rama `master` de este repositorio:** requisitos y spec (`ia_contexto/`, con el F-02 firmado como fuente que manda), skills (`.claude/`, `.agents/`), exportaciones de los flujos (`flujos n8n/`) y `scripts/`, además del frontend enlazado como submódulo.

## Objetivo y funcionalidades

Un repositorio clasificado (**Dependencia → Año → Asunto**, cada asunto con su código TRD), auditable y conectado al correo institucional:

- **Catálogos** (Administración): dependencias, TRD, asuntos, tipos documentales, programas, niveles, ubicaciones físicas (Carro → Estante → Bandeja), usuarios y perfiles, parámetros y plantillas de correo. Importación desde Excel.
- **Centro de cargas**: cargas de documentos e historias por lotes, con avance, duplicados (mismo SHA-256 en el mismo expediente) e informe.
- **Transferencias documentales** anuales (hasta el año actual − 2): físicas (inventario FUID + acta) y digitales (FUID + archivos).
- **Clasificación y archivo**: bandejas *Por clasificar* / *Clasificados*, árbol del archivo, visor PDF, búsqueda avanzada.
- **Comunicaciones por correo** (Bandeja, con n8n): recepción, remisión a dependencias, respuesta al remitente, recordatorios, correos sin asociar e histórico. Consecutivos `ENT|SAL|INT-AAAA-NNNNNN` asignados por la base.
- **Historias académicas**: árbol Estado → Año → Nivel → Programa → estudiante, ficha y carga masiva.
- **App móvil (PWA)** para escanear y cargar desde el celular.
- **Control**: perfiles fijos (Archivo Central, Dependencia, Registro Académico, Secretaría General, Administrador), permisos por perfil y dependencia, **auditoría inmutable** (también de intentos denegados) y anulación con motivo, **sin borrado físico**.

## Arquitectura y tecnologías

```text
 Navegador / celular
        │  (sesión de NOVA: token JWT)
        ▼
 ┌────────────────────────────┐        valida el token        ┌──────────────────────┐
 │ Frontend NOVA (repo aparte)│──────────────────────────────►│ Backend de NOVA      │
 │ React + Vite · módulo en   │                                │ GET /api/users/perfil│
 │ el Panel de Área           │                                └──────────▲───────────┘
 └─────────────┬──────────────┘                                           │
               │ HTTPS  VITE_SGD_API_URL (…/api) + token                  │
               ▼                                                          │
 ┌────────────────────────────┐───────────────────────────────────────────┘
 │ Backend SGD (Next.js 16)   │◄────── n8n (Bandeja de comunicaciones: F1–F6)
 │ backned_sistema_gestion_   │        POST /api/n8n/*  (N8N_SERVICE_TOKEN)
 │ documental/  · app/api     │
 └──────┬──────────────┬──────┘
        │ pg (SQL)     │ archivos
        ▼              ▼
 ┌──────────────┐  ┌───────────────────────────┐
 │ PostgreSQL 18│  │ Carpetas locales          │
 │ (database/)  │  │ RAIZ_ARCHIVOS (volumen)   │
 └──────────────┘  └───────────────────────────┘
```

| Capa | Tecnología | Dónde |
| --- | --- | --- |
| Frontend | React 18 + TypeScript + Vite 6 + Tailwind v4 + shadcn/ui, dentro de NOVA | Repo `DavidM3-M/NOVA_FT` (fuera de `main`) |
| Backend | Next.js 16 (solo rutas `app/api`), TypeScript 5, driver `pg` | `backned_sistema_gestion_documental/` |
| Base de datos | **PostgreSQL 18 propio** (sin Supabase, D-31): migraciones SQL, funciones `fn_*`/`n8n_*`, triggers, RLS | `database/` |
| Automatización | n8n (solo la Bandeja de comunicaciones; habla solo con el backend) | Contrato en `database/n8n/`; exportaciones en `flujos n8n/` de la rama `master` |
| Despliegue | Docker + Docker Compose | `despliegue/`, `backned_sistema_gestion_documental/Dockerfile` |

### Cómo funciona cada parte

- **Frontend.** El módulo es un componente más del Panel de Área de NOVA (repo NOVA_FT: `src/app/pages/archivo-central/`, `…/comunicaciones/`). Reutiliza el token de la sesión de NOVA y llama al backend del SGD (`src/app/lib/sgdApi.ts`, base `VITE_SGD_API_URL`). Solo entra el rol *área* de NOVA (D-30); lo que puede hacer cada persona lo decide su perfil del SGD.
- **Backend.** Valida cada token contra NOVA, sincroniza a la persona en la tabla `usuario` y revisa su perfil. Expone la API REST del módulo y las APIs que usa n8n. Guarda los archivos en carpetas (`RAIZ_ARCHIVOS`) y su referencia (id, ruta, hash) en la tabla `archivo`; nunca binarios en la base. Se conecta a PostgreSQL directo (`lib/db.ts`) con el rol `sgd_backend`. Detalle: [backned_sistema_gestion_documental/README.md](backned_sistema_gestion_documental/README.md).
- **Base de datos.** Concentra las reglas de negocio: consecutivos atómicos por tipo y año, estados de las comunicaciones, permisos por perfil (`permiso_perfil`), auditoría inmutable, bloqueo de borrado y RLS en todas las tablas. Se instala y actualiza con `database/scripts/instalar_local.sh`, que lleva la cuenta de las migraciones aplicadas. Detalle: [database/README.md](database/README.md).

## Estructura del repositorio

```text
.
├── README.md / README_DEPLOY.md       # este archivo y la guía de producción
├── CLAUDE.md / AGENTS.md              # reglas del proyecto para el equipo y los asistentes
├── backned_sistema_gestion_documental/
│   ├── app/api/<recurso>/route.ts     # rutas REST; app/api/n8n/ = APIs que llama n8n; app/api/salud = prueba de vida
│   ├── lib/                           # db (PostgreSQL), auth (NOVA), errors, catálogos, comunicaciones, archivos, n8n…
│   ├── tests/                         # pruebas (node --test); db.test.mjs = integración con la base
│   ├── Dockerfile                     # imagen de producción (Next.js standalone)
│   └── .env.example                   # variables del backend (sin valores reales)
├── database/
│   ├── migrations/                    # migraciones SQL en orden
│   ├── seed.sql / seed_demo.sql       # configuración obligatoria / datos ficticios de desarrollo
│   ├── tests/pruebas_reglas.sql       # pruebas de reglas de negocio
│   ├── scripts/                       # instalar_local.sh, probar_local.sh, armar_instalacion.sh
│   └── n8n/                           # contrato de las APIs para n8n
└── despliegue/
    ├── docker-compose.yml             # producción: PostgreSQL + migraciones + backend
    ├── docker-compose.dev.yml         # desarrollo: solo PostgreSQL en localhost
    ├── .env.ejemplo                   # variables de producción (sin valores)
    └── respaldar.sh                   # respaldo de base y archivos
```

## Requisitos previos (desarrollo)

- **Git**.
- **Node.js 24** y npm.
- **Docker Desktop** (o Docker Engine + Compose v2) para la base de datos. Alternativa: PostgreSQL 18 instalado.
- Acceso a una instancia de **NOVA** (backend) para iniciar sesión; sin ella, el backend acepta un token de desarrollo (`SGD_DEV_TOKEN`, solo con `next dev`).

## Instalación local

```bash
git clone https://github.com/dybala1812/Sistema-de-gesti-n-documental-2.0.git sgd     # rama main
cd sgd
```

**1. Base de datos** (PostgreSQL 18 en `localhost:5432`, con migraciones y `seed.sql`):

```bash
docker compose -f despliegue/docker-compose.dev.yml up -d
docker compose -f despliegue/docker-compose.dev.yml logs migraciones        # termina en ">>> Base lista"
docker compose -f despliegue/docker-compose.dev.yml exec db psql -U postgres -d sgd -f /database/seed_demo.sql   # datos ficticios (opcional)
```

**2. Backend** (`http://localhost:3000`):

```bash
cd backned_sistema_gestion_documental
cp .env.example .env.local
# En .env.local: DATABASE_URL=postgres://sgd_backend:sgd_backend_dev@localhost:5432/sgd
#                NOVA_API_URL=<backend de NOVA>   y, para probar sin NOVA, SGD_DEV_TOKEN=<valor largo al azar>
npm install
npm run dev
curl http://localhost:3000/api/salud        # {"ok":true,"bd":true}
```

**3. Frontend** (`http://localhost:5173`, repo aparte):

```bash
git clone -b desarrollo-archivo-central https://github.com/DavidM3-M/NOVA_FT.git
cd NOVA_FT
cp .env.example .env                        # VITE_SGD_API_URL=http://localhost:3000/api y la URL del backend de NOVA (VITE_API_URL)
npm install
npm run dev
```

Entrar a NOVA con una cuenta de rol *área* y abrir el módulo desde el Panel de Área. La primera vez, la persona queda registrada sin perfil; un Administrador le asigna el perfil en Administración › Catálogos › Usuarios. El primer administrador se asigna a mano:

```bash
docker compose -f despliegue/docker-compose.dev.yml exec db psql -U postgres -d sgd -c "update usuario set perfil = 'administrador' where email = '<correo>';"
```

## Pruebas

```bash
bash database/scripts/probar_local.sh --docker        # base: migraciones, 164 reglas, concurrencia de consecutivos y permisos
cd backned_sistema_gestion_documental
npm test                                              # unitarias del backend
SGD_DB_PRUEBAS_URL=postgres://sgd_backend:sgd_backend_dev@localhost:5432/sgd npm test   # + integración con la base de desarrollo
npx tsc --noEmit && npm run lint && npm run build
```

## Forma de trabajo

Reglas de negocio que nunca se rompen: ver [CLAUDE.md](CLAUDE.md). El tablero (tareas `SGD-NNN`) y las decisiones vinculantes (`ia_contexto/spec/decisiones.md`) están en la rama `master`. Normativa: Ley 594/2000, Decreto 1080/2015, Ley 1581/2012 (datos personales: nunca en logs, URLs ni datos de prueba reales) y Decreto 1377/2013.
