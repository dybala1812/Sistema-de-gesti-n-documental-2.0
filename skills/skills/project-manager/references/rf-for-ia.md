# RF FOR IA — Formato de Especificación Verificable

Formato explícito y verificable para describir tareas de desarrollo, pensado para que un agente de IA entienda exactamente qué construir sin tener que inferir intención.

---

## 1. Especificación del producto

Qué se quiere construir, objetivo, usuarios involucrados.

```
Producto: Sistema de inventario

Objetivo:
Gestionar entradas, salidas y existencias de productos.

Usuarios:
- Administrador
- Vendedor
- Bodeguero
```

---

## 2. Reglas de negocio (BR)

Explícitas, numeradas, sin ambigüedad.

```
BR-001
Un producto no puede tener existencia negativa.

BR-002
Solo ADMIN puede eliminar productos.

BR-003
Una salida debe disminuir la existencia disponible.

BR-004
Una entrada debe aumentar la existencia disponible.
```

---

## 3. Criterios de aceptación (Given / When / Then)

Escenarios concretos y verificables.

```
Scenario: Registrar salida de producto

Given el producto tiene 20 unidades
When el usuario registra una salida de 5 unidades
Then la existencia debe quedar en 15 unidades
```

---

## 4. Contratos técnicos

Para que la IA sepa exactamente qué forma tienen las peticiones y respuestas.

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
  "id": "...",
  "name": "Martillo",
  "price": 25000,
  "stock": 10
}
```

---

## 5. Especificación ejecutable / tests

Requisitos comprobables mediante pruebas.

```
TEST-001

Entrada:
stock = 20
cantidadSalida = 5

Resultado esperado:
stock = 15
```

---

## Estructura de carpetas por proyecto

```
/spec
  ├── product.md
  ├── requirements.md
  ├── business-rules.md
  ├── architecture.md
  ├── api.yaml
  ├── data-model.md
  └── acceptance-tests/
       ├── products.md
       └── inventory.md
```

## Flujo de una feature

```
FEATURE
  ↓
REQUIREMENTS
  ↓
BUSINESS RULES
  ↓
ACCEPTANCE CRITERIA
  ↓
API / DATA CONTRACT
  ↓
TESTS
  ↓
CODE
```

## Integración con el gestor de proyectos

Cada ítem que se chulea en el tablero puede referenciar un archivo dentro de `/spec` en vez de (o además de) una descripción libre en `tareas-por-realizar.md`. Así, cuando Claude Code toma la tarea, no solo lee el nombre de la tarea sino su especificación completa.
