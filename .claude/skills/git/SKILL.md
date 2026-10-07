---
name: git
description: Flujo de trabajo Git de {{PROYECTO}} — ramas, Conventional Commits con referencia a tareas, pull requests, hotfix y reversión. Úsala antes de crear ramas, hacer commits, abrir PRs o fusionar.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Git — Flujo de trabajo y Conventional Commits

## Ramas

| Rama | Descripción | Regla |
|---|---|---|
| `{{RAMA_PRODUCCION}}` | Código desplegado y funcionando en producción | **Nadie hace commit directo.** Solo recibe merges desde `{{RAMA_DESARROLLO}}` (release) o desde `hotfix/*` |
| `{{RAMA_DESARROLLO}}` | Integración de todas las tareas terminadas; base de las ramas nuevas | Cada tarea se fusiona aquí antes de considerarse lista |
| `feature/{{PREFIJO_TAREAS}}-XXX-descripcion` | Una rama por tarea o historia. Ej.: `feature/{{PREFIJO_TAREAS}}-001-login` | Se crea desde `{{RAMA_DESARROLLO}}` y vuelve a ella por pull request |
| `fix/{{PREFIJO_TAREAS}}-XXX-descripcion` | Corrección no urgente | Igual que `feature/` |
| `hotfix/descripcion` | Solo correcciones urgentes en producción | Se crea desde `{{RAMA_PRODUCCION}}`, se fusiona a `{{RAMA_PRODUCCION}}` con etiqueta y luego a `{{RAMA_DESARROLLO}}` |

> Si el proyecto trabaja con una sola rama (proyecto personal o prototipo), `project-setup` deja `{{RAMA_DESARROLLO}}` = `{{RAMA_PRODUCCION}}` y elimina la parte de release.

### Flujo típico para una tarea

1. Estar en `{{RAMA_DESARROLLO}}` actualizada.
2. Crear `feature/{{PREFIJO_TAREAS}}-XXX-descripcion`.
3. Trabajar con commits pequeños y convencionales.
4. Verificar (ver "Antes de subir").
5. Subir la rama y abrir un pull request hacia `{{RAMA_DESARROLLO}}`.
6. Revisión (compañero o usuario) → merge → borrar la rama.

## Conventional Commits

Formato:

```
<tipo>(<módulo>): <descripción> ({{PREFIJO_TAREAS}}-XXX)
```

| Tipo | Cuándo se usa | Ejemplo |
|---|---|---|
| `feat` | Nueva funcionalidad | `feat(auth): login con JWT ({{PREFIJO_TAREAS}}-001)` |
| `fix` | Corrección de un defecto | `fix(api): valida email duplicado ({{PREFIJO_TAREAS}}-004)` |
| `docs` | Documentación | `docs(readme): instrucciones de despliegue` |
| `test` | Pruebas | `test(usuarios): casos de valores límite` |
| `refactor` | Cambio interno sin alterar comportamiento | `refactor(repo): extrae consulta a un método` |
| `style` | Formato o estilos sin cambiar la lógica | `style(ui): ajusta espaciado de cards` |
| `perf` | Mejora de rendimiento | `perf(lista): virtualiza el listado` |
| `chore` | Configuración, dependencias, tareas de mantenimiento | `chore(deps): actualiza framework` |

### Reglas

- Cada commit de código referencia la tarea que atiende (`{{PREFIJO_TAREAS}}-XXX`). `docs`/`chore` sueltos pueden omitirla.
- La descripción explica **qué cambió** sin tener que abrir el código; en imperativo o presente, minúscula, sin punto final.
- Idioma de los mensajes: {{IDIOMA_COMMITS}}.
- Un commit = un cambio lógico. No mezclar refactor con feature.
- Cambio que rompe compatibilidad: `feat(api)!: ...` y explicar en el cuerpo `BREAKING CHANGE: ...`.

### Mensajes que no se aceptan

`cambios`, `avance`, `update`, `fix`, `wip`, `asdf`, o cualquier mensaje sin tipo y descripción clara.

## Antes de subir

```bash
cd {{DIR_APP}}
{{CMD_LINT}}
{{CMD_TEST}}
{{CMD_BUILD}}
```

- Si alguno falla, no se sube como evidencia de tarea terminada.
- Revisar `git status` y `git diff --staged`: nada de `.env`, credenciales, `node_modules/`, builds ni archivos personales.
- Preferir `git add <archivos>` a `git add .` cuando hay cambios ajenos a la tarea.

## Comandos

### Configuración inicial (una vez)

```bash
git config --global user.name "Tu Nombre"
git config --global user.email "tu@email.com"

# Opcional: validar los mensajes con un hook
npm install --save-dev @commitlint/cli @commitlint/config-conventional husky
```

### Flujo normal

```bash
# 1. Actualizar y crear la rama
git checkout {{RAMA_DESARROLLO}}
git pull origin {{RAMA_DESARROLLO}}
git checkout -b feature/{{PREFIJO_TAREAS}}-005-adjuntar-documento

# 2. Commits convencionales
git add src/documentos/
git commit -m "feat(documentos): permite adjuntar PDF ({{PREFIJO_TAREAS}}-005)"

# 3. Subir y abrir pull request
git push -u origin feature/{{PREFIJO_TAREAS}}-005-adjuntar-documento

# 4. Tras la aprobación (si se fusiona en local)
git checkout {{RAMA_DESARROLLO}}
git pull origin {{RAMA_DESARROLLO}}
git merge --no-ff feature/{{PREFIJO_TAREAS}}-005-adjuntar-documento
git push origin {{RAMA_DESARROLLO}}

# 5. Borrar la rama
git branch -d feature/{{PREFIJO_TAREAS}}-005-adjuntar-documento
git push origin --delete feature/{{PREFIJO_TAREAS}}-005-adjuntar-documento
```

### Mantener la rama al día

```bash
git fetch origin
git rebase origin/{{RAMA_DESARROLLO}}   # solo en ramas propias que nadie más usa
```

### Hotfix

```bash
git checkout {{RAMA_PRODUCCION}}
git pull origin {{RAMA_PRODUCCION}}
git checkout -b hotfix/crash-inicio
git commit -m "fix(core): corrige crash al iniciar (HOTFIX-001)"

git checkout {{RAMA_PRODUCCION}}
git merge --no-ff hotfix/crash-inicio
git tag -a v1.0.1 -m "Hotfix: crash al iniciar"
git push origin {{RAMA_PRODUCCION}} --tags

git checkout {{RAMA_DESARROLLO}}
git merge --no-ff hotfix/crash-inicio
git push origin {{RAMA_DESARROLLO}}
```

### Deshacer

```bash
# Commit ya subido: crear un commit inverso (seguro, no reescribe historia)
git revert --no-edit <hash>

# Último commit local NO subido: deshacerlo y conservar los cambios
git reset --soft HEAD~1

# Corregir el mensaje del último commit local NO subido
git commit --amend -m "fix(api): mensaje correcto ({{PREFIJO_TAREAS}}-004)"
```

## Prohibido para el agente sin autorización explícita del usuario

- `git push --force` (si hace falta, solo `--force-with-lease` sobre ramas propias).
- `git reset --hard`, `git clean -fd`, borrar ramas remotas ajenas.
- Commits directos en `{{RAMA_PRODUCCION}}`.
- Reescribir historia ya publicada en ramas compartidas.
- Subir secretos. Si se subió uno por error: avisar al usuario y rotar la clave; borrarlo del historial no basta.

## Relación con otras skills

- `project-manager`: el ID de la tarea del tablero es el que va en la rama y en el commit; al cerrar, el hash del commit se registra en `historial.md`.
- `testing`: define los comandos de "Antes de subir".
- `desarrollo`: remite aquí para el criterio de commits.
