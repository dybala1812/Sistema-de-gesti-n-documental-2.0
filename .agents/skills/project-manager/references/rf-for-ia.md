# RF FOR IA — Formato de Especificación Verificable

Formato explícito y verificable para describir tareas de desarrollo, pensado para que un agente de IA entienda exactamente qué construir sin tener que inferir la intención.

Si el proyecto tiene un documento fuente de requisitos, las specs de `ia_contexto/spec/` lo traducen a este formato y **conservan sus IDs** (`RF-xxx`, `RNF-xxx`, `RN-xxx`, `HU-xxx`). Si no lo tiene, usa los IDs de este documento.

> Los ejemplos usan un sistema de inventario genérico solo para mostrar el formato. Reemplázalos por el dominio real del proyecto.

---

## 1. Especificación del producto (`spec/product.md`)

Qué se construye, para qué y para quién.

```
Producto: Sistema de inventario
Documento fuente: (nombre, versión y fecha, si existe)

Objetivo:
Gestionar entradas, salidas y existencias de productos.

Usuarios / roles:
- Administrador
- Vendedor
- Bodeguero

Fuera de alcance:
- Facturación electrónica
```

---

## 2. Requisitos (`spec/requirements.md`)

Funcionales (RF) y no funcionales (RNF), uno por bloque, con un ancla para enlazarlos desde las tareas.

```
### RF-001 — Registrar salida de producto
Prioridad: alta
Rol: Bodeguero
Descripción: El sistema permite registrar la salida de unidades de un producto existente.
Reglas: BR-001, BR-003
Criterios: ver acceptance-tests/inventario.md#rf-001

### RNF-001 — Tiempo de respuesta
El listado de productos responde en menos de 2 s con 10.000 registros.
```

---

## 3. Reglas de negocio (`spec/business-rules.md`)

Explícitas, numeradas y sin ambigüedad. (Si el documento fuente usa otro prefijo, como `RN-`, se conserva.)

```
BR-001
Un producto no puede tener existencia negativa.

BR-002
Solo el rol Administrador puede eliminar productos.

BR-003
Una salida disminuye la existencia disponible.

BR-004
Una entrada aumenta la existencia disponible.
```

---

## 4. Criterios de aceptación (Dado / Cuando / Entonces)

Escenarios concretos y verificables. Se puede escribir en español (Dado/Cuando/Entonces) o en inglés (Given/When/Then); mantener uno solo en todo el proyecto.

```
Escenario: Registrar salida de producto (RF-001)

Dado que el producto tiene 20 unidades
Cuando el usuario registra una salida de 5 unidades
Entonces la existencia queda en 15 unidades

Escenario: Salida mayor a la existencia (RF-001, BR-001)

Dado que el producto tiene 3 unidades
Cuando el usuario registra una salida de 5 unidades
Entonces el sistema rechaza la operación con el mensaje "No hay unidades suficientes (disponibles: 3)"
Y la existencia sigue en 3 unidades
```

---

## 5. Contratos técnicos (`spec/api.md` o `api.yaml`)

La forma exacta de peticiones y respuestas, incluidos los errores.

```
POST /api/products

Request:
{
  "name": "Martillo",
  "price": 25000,
  "stock": 10
}

Response 201:
{
  "id": "…",
  "name": "Martillo",
  "price": 25000,
  "stock": 10
}

Response 422:
{ "error": "VALIDATION_ERROR", "fields": { "price": "Debe ser mayor que 0" } }
```

Valores ilustrativos o pendientes de confirmar se marcan así: *(ilustrativo — confirmar con el cliente)*.

---

## 6. Especificación ejecutable / tests

Requisitos comprobables con pruebas. ID sugerido: `TEST-<requisito>-<n>`.

```
TEST-RF-001-01

Entrada:
stock = 20
cantidadSalida = 5

Resultado esperado:
stock = 15
```

---

## 7. Decisiones (`spec/decisiones.md`)

```
## AAAA-MM-DD — D-001: <título>
Contexto: …
Decisión: …
Decidió: <usuario / cliente / equipo>
Afecta: RF-001, BR-003

## Preguntas abiertas
- P-001: ¿El consecutivo se reinicia cada año? (pendiente con el cliente)
```

---

## Estructura de carpetas

```
ia_contexto/spec/
  ├── product.md
  ├── requirements.md
  ├── business-rules.md
  ├── decisiones.md
  ├── trazabilidad.md     (opcional)
  ├── architecture.md     (cuando exista)
  ├── api.md | api.yaml   (cuando exista)
  ├── data-model.md       (cuando exista)
  └── acceptance-tests/   (opcional, un archivo por módulo)
```

## Flujo de una funcionalidad

```
REQUISITO (RF / HU)
  ↓
REGLAS DE NEGOCIO
  ↓
CRITERIOS DADO / CUANDO / ENTONCES
  ↓
CONTRATO API / MODELO DE DATOS
  ↓
PRUEBAS
  ↓
CÓDIGO
  ↓
TRAZABILIDAD (requisito → tarea → prueba → commit)
```

## Integración con el tablero

Cada tarea del tablero referencia su spec (`Spec: ia_contexto/spec/requirements.md#rf-001`). Así, cuando un agente toma la tarea, no solo lee su nombre sino su especificación completa.
