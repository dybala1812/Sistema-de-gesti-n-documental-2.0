# Matriz de trazabilidad — SGD · Módulo Archivo Central

Fuente: F-02 v1.1 §8. Se inicia aquí y se cierra en el documento de pruebas (**F-05**): `ia_contexto/spec/acceptance-tests/F-05_plan_pruebas.md` (ronda 2026-10-27: solo lo implementado).
Completar "Tarea" y "Resultado" cuando el verificador devuelva la hoja del F-05.

| RF | HU | Pts | Sprint | Componente | Caso de prueba | Tarea | Resultado |
|---|---|---|---|---|---|---|---|
| RF-AC-001 | HU-AC-01 | 8 | — | Catálogos (backend) + pantalla Dependencias | Crear dependencia con código o correo repetido y verificar rechazo | SGD-010 | — |
| RF-AC-002 | HU-AC-01 | ↑ | — | Módulo TRD + pantalla | Importar TRD con código duplicado y verificar reporte | SGD-010 | — |
| RF-AC-003 | HU-AC-01 | ↑ | — | Catálogos + pantalla Asuntos | Mismo asunto en dos dependencias (válido) y en la misma (rechazo) | SGD-010 | — |
| RF-AC-004 | HU-AC-02 | 3 | — | Catálogos de apoyo | Inactivar un tipo documental en uso y verificar que no se elimina | SGD-011 | — |
| RF-AC-005 | HU-AC-03 | 5 | — | Usuarios y perfiles | Usuario inactivo no puede iniciar sesión | SGD-012 | — |
| RF-AC-006 | HU-AC-03 | ↑ | — | Parámetros + plantillas | Cambiar plantilla y verificar el siguiente correo enviado | SGD-012 | — |
| RF-AC-007 | HU-AC-04 | 8 | — | Centro de cargas + lotes | Lote con un duplicado y un inválido; verificar informe y reintento | SGD-020 | — |
| RF-AC-008 | HU-AC-05 | 5 | — | Servicio de carga + flujo F8 | Cargar el mismo PDF dos veces y verificar duplicado | SGD-021 | — |
| RF-AC-009 | HU-AC-06 | 8 | — | Transferencias + flujo F7 | Inventario con año 2025 en 2026: aviso y bloqueo | SGD-022 | — |
| RF-AC-010 | HU-AC-07 | 8 | — | Transferencias + flujos F7 y F8 | Transferencia digital: archivos asociados a su asunto | SGD-023 | — |
| RF-AC-011 | HU-AC-08 | 8 | — | Clasificación + visor | Clasificar y verificar expediente, TRD y auditoría | SGD-030 | — |
| RF-AC-012 | HU-AC-08 | ↑ | — | Flujo F11 (IA) | Sugerencia aceptada, modificada y descartada, auditadas | SGD-031 | — |
| RF-AC-013 | HU-AC-09 | 8 | — | Árbol de archivo + visor | Dependencia no ve carpetas de otra | SGD-032 | — |
| RF-AC-014 | HU-AC-09 | ↑ | — | Servicio de búsqueda | Buscar "385 del 29 de febrero" y por persona | SGD-032 | — |
| RF-AC-015 | HU-AC-10 | 8 | — | Flujo F1 + bandeja | Mismo correo leído dos veces: una sola comunicación | SGD-040 | — |
| RF-AC-016 | HU-AC-11 | 8 | — | Flujos F2 y F1 (rama respuesta) | Respuesta con etiqueta borrada se asocia por In-Reply-To | SGD-041 | — |
| RF-AC-017 | HU-AC-12 | 5 | — | Flujo F3 | Envío fallido no cierra la comunicación | SGD-042 | — |
| RF-AC-018 | HU-AC-13 | 5 | — | Flujo F4 + correos sin asociar | Una dependencia con 5 vencidas recibe un solo recordatorio | SGD-043 | — |
| RF-AC-019 | HU-AC-14 | 5 | — | Histórico + flujo F10 | Importar el mismo Excel dos veces sin duplicar | SGD-044 | — |
| RF-AC-020 | HU-AC-15 | 8 | — | Historias académicas | Registro Académico no ve historias de retirados | SGD-050 | — |
| RF-AC-021 | HU-AC-16 | 8 | — | Flujo F9 + lotes | Carga por carpetas ordena alfabéticamente y agrega a historias existentes | SGD-051 | — |
| RF-AC-022 | HU-AC-17 | 8 | — | PWA de escaneo | Escanear 3 páginas y subir desde el celular | SGD-060 | — |
| RF-AC-023 | HU-AC-18 | 5 | — | Guard de perfiles + auditoría | Intento sin permiso denegado y auditado | SGD-005 | — |
| RF-AC-024 | HU-AC-18 | ↑ | — | Servicio de anulación | Anular y verificar que el registro sigue en la base | SGD-005 | — |

Totales: 121 pts en 18 HU. Por sprint: pendiente del F-04.
