F-02
Especificación de requisitos de software — Módulo Archivo Central
Estructura basada en ISO/IEC/IEEE 29148. Versión 1.1, 7 de octubre de 2026.
▸ Este documento especifica únicamente el módulo Archivo Central del Sistema de Gestión Documental. La versión 1.1 incorpora las reuniones sobre transferencias documentales, historias académicas, revisión de mockups y el circuito de comunicaciones por correo. La firma del numeral 9 autoriza iniciar la construcción.
# 1. Introducción
## 1.1 Propósito del documento
| Este documento especifica los requisitos funcionales y no funcionales del módulo Archivo Central del Sistema de Gestión Documental de la Universidad Autónoma. Sirve de base para el diseño, desarrollo, pruebas y aceptación del módulo, y debe ser aprobado por el cliente (numeral 9) antes de iniciar su construcción. |
|---|

## 1.2 Alcance del producto
| El módulo reemplaza los Excel por año y los PDF por oficina con un único sistema donde se registra, custodia y consulta lo que llega al Archivo Central. Cubre: catálogos (dependencias, TRD, asuntos, tipos documentales, programas, usuarios, parámetros y plantillas); un centro de cargas; transferencias documentales físicas y digitales; clasificación con apoyo opcional de IA; archivo navegable por Dependencia, Año y Asunto; búsqueda avanzada; el circuito de comunicaciones por correo (recepción, remisión a dependencias, respuesta al remitente y recordatorios); el registro histórico de comunicaciones; las historias académicas con carga masiva; y una aplicación web para escanear desde el celular. Quedan fuera: las historias laborales, el archivo de gestión de cada oficina y la radicación del sistema que ya usa la universidad. Se parte de que los documentos son digitales desde 2020; los anteriores se custodian en físico y se registran por su inventario. |
|---|

▸ Pendiente de confirmar con la jefatura (Hoover): el circuito de comunicaciones por correo se parece a una radicación. Se debe confirmar que entra en este proyecto y no duplica el sistema de radicación existente.
## 1.3 Definiciones, acrónimos y abreviaturas
| Término | Definición |
|---|---|
| Archivo de gestión | Archivo de cada oficina donde los documentos están en trámite y consulta frecuente; permanecen allí 2 años. |
| Archivo Central | Archivo que custodia los documentos transferidos por las dependencias y las historias de estudiantes retirados y graduados. |
| Transferencia documental | Entrega anual de una dependencia al Archivo Central, física (cajas) o digital (archivos), acompañada de su inventario y acta. |
| FUID | Formato Único de Inventario Documental: Excel donde la dependencia relaciona cajas, carpetas, asuntos, fechas, folios y rangos que entrega. |
| TRD | Tabla de Retención Documental: series, subseries, tiempos de retención y disposición final. |
| Asunto | Término del cliente para la serie documental (actas, circulares, resoluciones, etc.). Se define por dependencia. |
| Foliar / rotular | Numerar las hojas de una carpeta / identificar cajas y carpetas con su rótulo. |
| Historia académica | Expediente de un estudiante. Activa (en Registro Académico), retirado o graduado (en Archivo Central). |
| Comunicación | Correo o documento recibido, enviado o interno, identificado con consecutivo ENT, SAL o INT. |
| Lote de carga | Conjunto de archivos cargados en una operación, con su avance e informe. |
| Hash SHA-256 | Huella digital del archivo para detectar duplicados y verificar integridad. |
| Message-ID | Identificador único de un correo, usado para no registrarlo dos veces y asociar respuestas. |
| PWA | Aplicación web instalable en el celular, con acceso a la cámara. |
| n8n | Herramienta de automatización que ejecuta los flujos de correo, cargas e IA. |

## 1.4 Referencias
| Ley 594 de 2000 (Ley General de Archivos) y Decreto 1080 de 2015. Ley 1581 de 2012 y Decreto 1377 de 2013 (protección de datos personales). ISO/IEC/IEEE 29148 e ISO/IEC 25010. F-02 Archivo Central v1.0; documento "Flujos n8n — Archivo Central"; esquemas SQL y flujos n8n de digitalización y clasificación del equipo. Audios de requisitos del cliente: Archivo Central, transferencias documentales y revisión de mockups. |
|---|

# 2. Descripción general
## 2.1 Perspectiva del producto
| Hoy el archivo se lleva en Excel por año y PDF mensuales por oficina, y las comunicaciones se reciben, escanean y remiten por correo a mano. El módulo centraliza todo en un repositorio clasificado, auditable y conectado al correo institucional. Arquitectura: backend con base de datos PostgreSQL en Supabase; archivos en el almacenamiento local del sistema (servidor de la aplicación), con solo ruta y hash en la base; frontend web y una PWA para el celular; flujos n8n que leen y envían correos, procesan cargas y escriben directamente en Supabase. Los consecutivos se generan con una función atómica de la base de datos. |
|---|

## 2.2 Funciones principales
| Función | Descripción |
|---|---|
| Catálogos | Dependencias, TRD, asuntos por dependencia, tipos documentales, programas, ubicaciones, usuarios, parámetros y plantillas de correo. |
| Centro de cargas | Punto único para todas las cargas, con lotes, avance, duplicados e informe. |
| Transferencias | Física (solo inventario y acta) y digital (inventario y archivos), con validación de la regla de 2 años. |
| Clasificación y archivo | Por clasificar y clasificados; árbol Dependencia, Año, Asunto; visor; sugerencia con IA. |
| Comunicaciones | Bandeja por estados: recepción por correo, remisión a dependencias, respuesta al remitente, recordatorios e histórico. |
| Historias académicas | Árbol Estado, Año, Nivel, Programa; ficha del estudiante; carga masiva por carpetas. |
| App móvil | Escaneo con la cámara y carga directa. |
| Control | Perfiles, auditoría y anulación sin borrado. |

## 2.3 Características de los usuarios
| Perfil | Descripción | Permisos en el módulo |
|---|---|---|
| Archivo Central | Recibe transferencias, carga, clasifica y custodia documentos e historias; gestiona las comunicaciones por correo. Usuario principal. | Acceso total al módulo, salvo usuarios y parámetros sensibles. |
| Dependencia | Oficinas productoras que transfieren cada año y responden las comunicaciones que se les remiten. | Transferir y consultar solo lo de su dependencia. |
| Registro Académico | Gestiona las historias de estudiantes activos. | Cargar y consultar historias activas. |
| Secretaría General | Consulta documentos institucionales, comunicaciones e historias. | Consulta. |
| Administrador | Configura catálogos, usuarios, parámetros y revisa la auditoría. | Catálogos, usuarios, parámetros y auditoría. |

## 2.4 Restricciones
| Tecnológicas: Supabase (PostgreSQL), almacenamiento local del sistema, n8n con acceso al buzón institucional y escritura directa en Supabase, frontend React y PWA. Normativas: Ley 594 de 2000, Decreto 1080 de 2015 y Ley 1581 de 2012. No se permite borrado definitivo desde la aplicación. Los perfiles de usuario son fijos en esta versión. Alcance académico sujeto al cronograma de la práctica profesional. |
|---|

## 2.5 Supuestos y dependencias
| El cliente entregará la TRD, los asuntos por dependencia, los correos oficiales de cada dependencia, un FUID de ejemplo y los Excel históricos. La universidad dará acceso al buzón de Archivo Central (proveedor por confirmar: Google Workspace o Microsoft 365) y el espacio de almacenamiento en su servidor. Las historias ya escaneadas se entregan organizadas por carpetas, con una convención de nombres acordada. La sugerencia con IA depende de un servicio externo y es opcional. |
|---|

▸ Pendientes de confirmar: orden de las carpetas de historias (Estado, Año, Nivel, Programa); plantilla del FUID; espacio de almacenamiento para ~30.000 historias; si el sistema debe generar rótulos de caja y carpeta; si la respuesta al estudiante se vincula a su historia académica.
# 3. Requisitos funcionales
RF-AC-001 — Gestionar dependencias
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-001 |
| Nombre | Gestionar dependencias |
| Descripción | Mantener el catálogo de dependencias de la universidad. Es el primer nivel del archivo y su correo oficial permite remitir comunicaciones y reconocer sus respuestas. |
| Actor | Administrador |
| Precondición | Sesión iniciada como Administrador. |
| Flujo principal | 1. El usuario abre Catálogos > Dependencias y elige "Nuevo" o edita una existente. 2. Diligencia código, nombre, dependencia superior (opcional), responsable, correo oficial y estado. 3. El sistema valida que el código y el correo sean únicos y guarda. |
| Flujos alternativos | Se puede importar el catálogo desde Excel con vista previa de errores. Una dependencia con documentos o comunicaciones no se elimina: solo se inactiva. |
| Postcondición | La dependencia queda disponible para transferencias, asuntos, clasificación y remisión de comunicaciones. |
| Prioridad | Alta |
| Origen | Primer audio de requisitos del cliente (Archivo Central) |

RF-AC-002 — Gestionar la Tabla de Retención Documental (TRD)
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-002 |
| Nombre | Gestionar la Tabla de Retención Documental (TRD) |
| Descripción | Mantener las series y subseries vigentes con su código, años en archivo de gestión (2), años en archivo central y disposición final. El código TRD se conserva como identificador de clasificación. |
| Actor | Administrador / Archivo Central |
| Precondición | Sesión iniciada con permiso sobre catálogos. |
| Flujo principal | 1. El usuario abre Catálogos > TRD y crea o edita una serie o subserie. 2. Diligencia código, nombre, descripción, años de gestión, años de archivo central y disposición final. 3. El sistema guarda y registra el cambio en la auditoría. |
| Flujos alternativos | Importación desde Excel con validación de códigos duplicados. Una serie con documentos asociados solo se inactiva. |
| Postcondición | La TRD queda disponible para asociar asuntos y calcular tiempos de retención. |
| Prioridad | Alta |
| Origen | Primer audio de requisitos del cliente (Archivo Central) |

RF-AC-003 — Gestionar asuntos por dependencia
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-003 |
| Nombre | Gestionar asuntos por dependencia |
| Descripción | Definir para cada dependencia su catálogo de asuntos (el cliente llama "asunto" a la serie documental: actas, circulares, resoluciones, convenios, comprobantes de egreso, etc.), cada uno vinculado a un código TRD. |
| Actor | Archivo Central / Administrador |
| Precondición | Existen la dependencia (RF-AC-001) y la TRD (RF-AC-002). |
| Flujo principal | 1. El usuario elige una dependencia y abre su catálogo de asuntos. 2. Crea o edita un asunto: nombre, código TRD, descripción y estado. 3. El sistema valida que el nombre no se repita dentro de esa dependencia. |
| Flujos alternativos | El mismo nombre puede existir en dependencias distintas. Un asunto con documentos solo se inactiva. La descripción alimenta la sugerencia con IA (RF-AC-012). |
| Postcondición | El asunto queda disponible como tercer nivel del árbol y como opción de clasificación. |
| Prioridad | Alta |
| Origen | Primer audio de requisitos del cliente (Archivo Central) |

RF-AC-004 — Gestionar tipos documentales, programas académicos y ubicaciones físicas
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-004 |
| Nombre | Gestionar tipos documentales, programas académicos y ubicaciones físicas |
| Descripción | Mantener los catálogos de apoyo: tipos documentales (acta, memorando, circular, resolución, comprobante de egreso, etc.), programas académicos con su nivel (pregrado o posgrado) y, de forma opcional, ubicaciones físicas (bodega, estante, módulo). |
| Actor | Archivo Central / Administrador |
| Precondición | Sesión iniciada con permiso sobre catálogos. |
| Flujo principal | 1. El usuario abre el catálogo correspondiente. 2. Crea, edita o inactiva registros desde una lista con buscador y filtro por estado. 3. El sistema valida nombres únicos y guarda con auditoría. |
| Flujos alternativos | Programas académicos admite importación desde Excel. El catálogo de ubicaciones físicas se activa solo si el cliente lo confirma. |
| Postcondición | Los catálogos quedan disponibles en clasificación, historias académicas y ubicación de cajas. |
| Prioridad | Media |
| Origen | Reunión de revisión de mockups con Archivo Central |

RF-AC-005 — Gestionar usuarios y perfiles
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-005 |
| Nombre | Gestionar usuarios y perfiles |
| Descripción | Crear y mantener los usuarios del sistema, asignando su dependencia y uno de los perfiles fijos del módulo (Archivo Central, Dependencia, Registro Académico, Secretaría General, Administrador). |
| Actor | Administrador |
| Precondición | Sesión iniciada como Administrador. |
| Flujo principal | 1. El usuario abre Catálogos > Usuarios. 2. Crea o edita un usuario: nombre, correo, dependencia, perfil y estado. 3. El sistema guarda y registra el cambio en la auditoría. |
| Flujos alternativos | Los perfiles son fijos en esta versión: no hay pantalla para crear roles. Un usuario inactivo no puede iniciar sesión, pero su historial se conserva. |
| Postcondición | El usuario puede iniciar sesión con los permisos de su perfil. |
| Prioridad | Alta |
| Origen | Decisión del equipo (octubre de 2026) |

RF-AC-006 — Gestionar parámetros y plantillas de correo
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-006 |
| Nombre | Gestionar parámetros y plantillas de correo |
| Descripción | Configurar los valores del módulo (años mínimos antes de transferir, tamaño máximo por archivo, formatos permitidos, plazo de respuesta de dependencias, frecuencia de recordatorios, umbral de la IA) y las plantillas de los correos automáticos. |
| Actor | Administrador / Archivo Central |
| Precondición | Sesión iniciada con permiso sobre catálogos. |
| Flujo principal | 1. El usuario abre Catálogos > Parámetros o Plantillas de correo. 2. Modifica el valor o el texto de la plantilla (acuse de recibo, remisión, devolución, respuesta, recordatorio, resumen). 3. El sistema valida rangos y campos obligatorios y guarda con auditoría. |
| Flujos alternativos | Las plantillas admiten campos variables (nombre, consecutivo, asunto, plazo). Se muestra una vista previa antes de guardar. |
| Postcondición | Los flujos automáticos usan los nuevos valores y textos desde ese momento. |
| Prioridad | Media |
| Origen | Reunión de revisión de mockups con Archivo Central |

RF-AC-007 — Centro de cargas y seguimiento de lotes
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-007 |
| Nombre | Centro de cargas y seguimiento de lotes |
| Descripción | Ofrecer un único punto de entrada para todas las cargas (documento individual, transferencia física, transferencia digital, historias académicas, registro histórico y app móvil), donde cada carga es un lote con avance, contadores e informe de resultados. |
| Actor | Archivo Central / Dependencia / Registro Académico |
| Precondición | Sesión iniciada con permiso para el tipo de carga. |
| Flujo principal | 1. El usuario abre el Centro de cargas y elige el tipo de carga. 2. Sigue el asistente: destino y datos, archivos, vista previa con validación, confirmación. 3. El sistema procesa el lote y muestra el avance. 4. Al terminar, muestra aceptados, duplicados y errores con su motivo. |
| Flujos alternativos | Un archivo con error no detiene el lote. El usuario puede reintentar solo los fallidos y descargar el informe del lote. |
| Postcondición | El lote queda registrado con su resultado y auditoría. |
| Prioridad | Alta |
| Origen | Reunión de revisión de mockups con Archivo Central |

RF-AC-008 — Cargar un documento individual
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-008 |
| Nombre | Cargar un documento individual |
| Descripción | Cargar un documento (PDF o imagen) con sus datos, calcular su huella SHA-256, detectar duplicados y guardarlo en el almacenamiento local del sistema. |
| Actor | Archivo Central |
| Precondición | Sesión iniciada; formato y tamaño permitidos. |
| Flujo principal | 1. El usuario selecciona dependencia, año y, si los conoce, asunto, tipo, consecutivo, fecha, caja y carpeta. 2. Adjunta el archivo; el sistema valida formato y tamaño y calcula el hash. 3. El sistema guarda el archivo y registra el documento. |
| Flujos alternativos | Si el hash ya existe en el mismo expediente, rechaza la carga e indica el documento duplicado. Si faltan datos de clasificación, el documento queda "por clasificar". |
| Postcondición | Documento almacenado con hash y estado "clasificado" o "por clasificar". |
| Prioridad | Alta |
| Origen | Primer audio de requisitos del cliente (Archivo Central) |

RF-AC-009 — Registrar una transferencia documental física
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-009 |
| Nombre | Registrar una transferencia documental física |
| Descripción | Registrar la transferencia anual de una dependencia que entrega cajas físicas. No se escanean los documentos: se guarda el inventario (FUID) y el acta que entrega la dependencia, con el detalle por caja. |
| Actor | Archivo Central |
| Precondición | Dependencia activa; inventario de la dependencia disponible. |
| Flujo principal | 1. El usuario crea la transferencia: dependencia, año, tipo "física" y funcionario que entrega. 2. Adjunta el acta o inventario (FUID) entregado por la dependencia, en Excel o PDF. 3. Si es Excel, el sistema lo lee y muestra el inventario por caja: carpeta o tomo, asunto, fecha inicial y final, folios y rango de consecutivos. 4. El sistema valida año, fechas y columnas obligatorias. 5. Al verificar las cajas contra el inventario, el usuario marca la transferencia como "recibida". |
| Flujos alternativos | Si el año supera el permitido (año actual menos 2), el sistema avisa y no permite confirmar. Las filas con errores se muestran para que la dependencia corrija el inventario. |
| Postcondición | Transferencia registrada con su inventario y acta adjunta, en estado "recibida". |
| Prioridad | Alta |
| Origen | Audio sobre transferencias documentales |

RF-AC-010 — Registrar una transferencia documental digital
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-010 |
| Nombre | Registrar una transferencia documental digital |
| Descripción | Registrar la transferencia de una dependencia que entrega documentos digitales (desde 2020): además del inventario, se cargan todos los archivos, ya organizados por asunto. |
| Actor | Dependencia / Archivo Central |
| Precondición | Dependencia activa; archivos e inventario disponibles. |
| Flujo principal | 1. El usuario crea la transferencia con tipo "digital". 2. Adjunta el inventario (FUID) como en RF-AC-009. 3. Carga los archivos indicando el asunto de cada grupo. 4. El sistema calcula hash, descarta duplicados, guarda los archivos y los asocia a dependencia, año y asunto. 5. Archivo Central revisa y marca la transferencia como "recibida". |
| Flujos alternativos | La revisión con IA (RF-AC-012) puede avisar de documentos que parecen de otro asunto. La transferencia puede completarse en varias sesiones. |
| Postcondición | Documentos digitales registrados y transferencia en estado "recibida". |
| Prioridad | Alta |
| Origen | Audio sobre transferencias documentales |

RF-AC-011 — Clasificar documentos
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-011 |
| Nombre | Clasificar documentos |
| Descripción | Completar los datos de los documentos que quedaron "por clasificar": tipo, consecutivo, fecha, caja, carpeta, asunto y código TRD. |
| Actor | Archivo Central |
| Precondición | Documento en estado "por clasificar". |
| Flujo principal | 1. El usuario abre "Por clasificar" y filtra por dependencia, año u origen. 2. Abre un documento: ve el PDF a un lado y el formulario al otro. 3. Diligencia o confirma los datos; el sistema propone el código TRD según el asunto. 4. Guarda; el documento pasa a "clasificado". |
| Flujos alternativos | Se puede reclasificar un documento clasificado dejando registro del cambio. Si el asunto no existe, el usuario con permiso lo crea (RF-AC-003). |
| Postcondición | Documento clasificado y asociado a su expediente, con auditoría. |
| Prioridad | Alta |
| Origen | Reunión de revisión de mockups con Archivo Central |

RF-AC-012 — Sugerir clasificación con inteligencia artificial
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-012 |
| Nombre | Sugerir clasificación con inteligencia artificial |
| Descripción | Proponer, a partir del contenido, el asunto de un documento o la dependencia de una comunicación recibida. La IA solo sugiere: una persona confirma. No se usa con historias académicas. |
| Actor | Archivo Central |
| Precondición | Documento o comunicación sin clasificar; asuntos con descripción. |
| Flujo principal | 1. El usuario pulsa "Sugerir con IA" o el sistema la pide al recibir un correo nuevo. 2. El flujo de IA lee el documento y devuelve asunto o dependencia sugeridos, confianza y justificación. 3. La sugerencia aparece precargada; el usuario la acepta, modifica o descarta. |
| Flujos alternativos | Si el servicio de IA falla o la confianza es baja, se clasifica manualmente. Cada sugerencia se registra en la auditoría. |
| Postcondición | Sugerencia registrada; la clasificación cambia solo con confirmación humana. |
| Prioridad | Baja |
| Origen | Decisión del equipo (octubre de 2026) |

RF-AC-013 — Navegar el archivo y consultar documentos clasificados
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-013 |
| Nombre | Navegar el archivo y consultar documentos clasificados |
| Descripción | Navegar un árbol de carpetas virtuales Dependencia, Año y Asunto, y consultar cada documento con sus datos (tipo, consecutivo, fecha, caja, carpeta, TRD) junto al visor del PDF. |
| Actor | Archivo Central / Dependencia / Secretaría General |
| Precondición | Documentos clasificados. |
| Flujo principal | 1. El usuario abre "Archivo". 2. Recorre dependencia, año y asunto; cada nodo muestra su cantidad de documentos. 3. Abre un documento en el visor junto a sus datos. 4. Descarga el archivo si su perfil lo permite. |
| Flujos alternativos | Una dependencia solo ve sus propias carpetas. Las descargas quedan auditadas. |
| Postcondición | Consulta realizada. |
| Prioridad | Alta |
| Origen | Primer audio de requisitos del cliente (Archivo Central) |

RF-AC-014 — Búsqueda avanzada
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-014 |
| Nombre | Búsqueda avanzada |
| Descripción | Buscar documentos y comunicaciones por año, mes, dependencia, tipo (entrada, salida o interno), asunto, consecutivo, persona y código TRD, con resultados paginados y vista previa. |
| Actor | Archivo Central / Dependencia / Secretaría General |
| Precondición | Información cargada. |
| Flujo principal | 1. El usuario abre "Buscar" e ingresa uno o varios criterios. 2. El sistema devuelve resultados paginados según los permisos del usuario. 3. El usuario abre el resultado en el visor. |
| Flujos alternativos | El consecutivo acepta formatos como "385" o "385 del 29 de febrero". Sin resultados, el sistema sugiere ampliar filtros. |
| Postcondición | Resultado mostrado; consultas a historias académicas auditadas. |
| Prioridad | Alta |
| Origen | Reunión de revisión de mockups con Archivo Central |

RF-AC-015 — Recibir y registrar comunicaciones por correo
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-015 |
| Nombre | Recibir y registrar comunicaciones por correo |
| Descripción | Registrar automáticamente cada correo que llega al buzón de Archivo Central (de estudiantes, terceros o dependencias), con sus adjuntos, consecutivo de entrada y acuse de recibo. |
| Actor | Sistema (flujo F1) / Archivo Central |
| Precondición | Buzón institucional conectado. |
| Flujo principal | 1. El flujo revisa el buzón cada pocos minutos. 2. Descarta respuestas automáticas, rebotes y correos ya procesados (por Message-ID). 3. Si es un correo nuevo, crea la comunicación de entrada con consecutivo (ENT-AAAA-NNNNNN), guarda los adjuntos y la deja en estado "Nueva". 4. Envía al remitente un acuse de recibo con su consecutivo. |
| Flujos alternativos | Si el correo es una respuesta de dependencia, se aplica RF-AC-016. Si no puede asociarse, va a "Correos sin asociar" (RF-AC-018). |
| Postcondición | Comunicación registrada en estado "Nueva" y visible en la bandeja. |
| Prioridad | Alta |
| Origen | Reunión de revisión de mockups con Archivo Central |

RF-AC-016 — Remitir a una dependencia y recibir su respuesta
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-016 |
| Nombre | Remitir a una dependencia y recibir su respuesta |
| Descripción | Enviar una comunicación, con los adjuntos elegidos, al correo de la dependencia que debe atenderla, y registrar automáticamente la respuesta que esta devuelva. |
| Actor | Archivo Central / Sistema (flujos F1 y F2) |
| Precondición | Comunicación en estado "Nueva"; dependencia con correo oficial. |
| Flujo principal | 1. El usuario pulsa "Remitir", elige la dependencia, el mensaje, los adjuntos y el plazo. 2. El sistema envía el correo con la etiqueta [SGD consecutivo] en el asunto y pasa la comunicación a "Remitida". 3. Cuando la dependencia responde, el flujo reconoce la etiqueta, guarda la respuesta y sus adjuntos y pasa la comunicación a "Respondida por dependencia". 4. Archivo Central recibe un aviso. |
| Flujos alternativos | Si la respuesta está incompleta, el usuario puede "Devolver" a la dependencia con otra plantilla (estado "Devuelta"). Si la dependencia borra la etiqueta, se usa el encabezado In-Reply-To. |
| Postcondición | Comunicación con la respuesta de la dependencia asociada. |
| Prioridad | Alta |
| Origen | Reunión de revisión de mockups con Archivo Central |

RF-AC-017 — Responder al remitente
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-017 |
| Nombre | Responder al remitente |
| Descripción | Enviar al estudiante o tercero la respuesta final desde el sistema, creando la comunicación de salida enlazada y cerrando la de entrada. |
| Actor | Archivo Central / Sistema (flujo F3) |
| Precondición | Comunicación en estado "Respondida por dependencia". |
| Flujo principal | 1. El usuario pulsa "Enviar respuesta"; el sistema precarga destinatario, plantilla y adjuntos de la dependencia. 2. El usuario revisa y envía. 3. El sistema crea la comunicación de salida (SAL-AAAA-NNNNNN) enlazada a la entrada. 4. La comunicación de entrada pasa a "Cerrada". |
| Flujos alternativos | Si el envío falla, el estado no cambia y la pantalla permite reintentar. Si el remitente es un estudiante identificado, la solicitud y la respuesta pueden quedar vinculadas a su historia académica (pendiente de confirmar). |
| Postcondición | Comunicación cerrada con su salida enlazada. |
| Prioridad | Alta |
| Origen | Reunión de revisión de mockups con Archivo Central |

RF-AC-018 — Recordatorios y correos sin asociar
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-018 |
| Nombre | Recordatorios y correos sin asociar |
| Descripción | Recordar automáticamente a las dependencias las comunicaciones remitidas sin respuesta pasado su plazo, enviar un resumen diario a Archivo Central y permitir asociar manualmente los correos que el sistema no pudo vincular. |
| Actor | Sistema (flujo F4) / Archivo Central |
| Precondición | Comunicaciones remitidas con fecha límite. |
| Flujo principal | 1. Cada día hábil el sistema busca comunicaciones "Remitida" o "Devuelta" vencidas. 2. Envía un único correo por dependencia con la lista de pendientes. 3. Envía a Archivo Central el resumen de nuevas, vencidas y por escalar. 4. En "Correos sin asociar", el usuario asocia cada correo a una comunicación o lo crea como nueva. |
| Flujos alternativos | No se recuerda la misma comunicación más de una vez cada 2 días hábiles; tras el tercer recordatorio se marca para escalar (valores configurables). |
| Postcondición | Recordatorios registrados en el historial de cada comunicación. |
| Prioridad | Media |
| Origen | Decisión del equipo (octubre de 2026) |

RF-AC-019 — Registro histórico de comunicaciones
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-019 |
| Nombre | Registro histórico de comunicaciones |
| Descripción | Consultar las comunicaciones recibidas, enviadas e internas en un calendario por año y mes, e importar los Excel históricos ("Autónoma 2024/2025/2026") adaptando su consecutivo y conservando el original. |
| Actor | Archivo Central / Secretaría General |
| Precondición | Comunicaciones registradas o archivos Excel disponibles. |
| Flujo principal | 1. El usuario abre Comunicaciones > Histórico y elige año y mes. 2. Filtra por recibidas, enviadas o internas y abre el detalle. 3. Para importar, carga el Excel, mapea columnas y revisa la vista previa. 4. El sistema crea los registros como comunicaciones cerradas. |
| Flujos alternativos | Las filas con consecutivo repetido en el mismo año se marcan para revisión. La importación se puede repetir sin duplicar. |
| Postcondición | Histórico consultable y unificado con las comunicaciones nuevas. |
| Prioridad | Alta |
| Origen | Primer audio de requisitos del cliente (Archivo Central) |

RF-AC-020 — Gestionar historias académicas
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-020 |
| Nombre | Gestionar historias académicas |
| Descripción | Custodiar las historias académicas en un árbol Estado (Retirados o Graduados), Año, Nivel (Pregrado o Posgrado), Programa y estudiantes en orden alfabético. Registro Académico gestiona las de estudiantes activos. |
| Actor | Archivo Central / Registro Académico / Secretaría General |
| Precondición | Programas cargados (RF-AC-004). |
| Flujo principal | 1. El usuario abre "Historias académicas" y recorre el árbol. 2. Busca al estudiante por nombre o documento. 3. Abre su ficha: datos básicos, estado de la historia y documentos con visor. 4. Agrega documentos o cambia el estado cuando el estudiante se gradúa o se retira. |
| Flujos alternativos | Registro Académico solo ve y carga historias activas; al cambiar a retirado o graduado, la historia pasa a custodia de Archivo Central. Cada consulta queda auditada. |
| Postcondición | Historia consultada o actualizada con trazabilidad. |
| Prioridad | Alta |
| Origen | Reunión de revisión de mockups con Archivo Central |

RF-AC-021 — Carga masiva de historias académicas
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-021 |
| Nombre | Carga masiva de historias académicas |
| Descripción | Migrar por carpetas las historias ya escaneadas (unas 30.000, desde los años 70 hasta 2024), ubicándolas en el árbol y ordenándolas alfabéticamente. |
| Actor | Archivo Central / Registro Académico |
| Precondición | Archivos escaneados organizados por carpetas. |
| Flujo principal | 1. El usuario elige el destino en el árbol (estado, año, nivel, programa) o sube una carpeta con esa estructura. 2. El sistema lee el nombre de cada archivo para identificar al estudiante y muestra la vista previa. 3. El usuario confirma; el sistema procesa por lotes con avance. 4. Al terminar entrega el resumen de cargados, duplicados y errores. |
| Flujos alternativos | Si el estudiante ya tiene historia, el documento se agrega a ella. La carga se puede pausar y retomar. La convención de nombres de archivo se acuerda con el cliente. |
| Postcondición | Historias cargadas y ordenadas alfabéticamente. |
| Prioridad | Alta |
| Origen | Reunión de revisión de mockups con Archivo Central |

RF-AC-022 — Escanear y cargar desde el celular
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-022 |
| Nombre | Escanear y cargar desde el celular |
| Descripción | Permitir, mediante una aplicación web instalable (PWA), escanear documentos con la cámara del celular, diligenciar sus datos y subirlos directamente al sistema. |
| Actor | Archivo Central |
| Precondición | Usuario con sesión en el celular. |
| Flujo principal | 1. El usuario inicia sesión en la app. 2. Escanea una o varias páginas con recorte automático y vista previa. 3. Diligencia dependencia, año, asunto, tipo, consecutivo, fecha, caja y carpeta. 4. Pulsa "Subir"; el sistema procesa la carga como RF-AC-008. |
| Flujos alternativos | Si se pierde la conexión, la app avisa y permite reintentar. Si faltan datos, el documento queda "por clasificar". |
| Postcondición | Documento cargado sin pasar por el computador. |
| Prioridad | Media |
| Origen | Reunión de revisión de mockups con Archivo Central |

RF-AC-023 — Controlar acceso y registrar auditoría
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-023 |
| Nombre | Controlar acceso y registrar auditoría |
| Descripción | Restringir cada función según el perfil y la dependencia del usuario, y registrar quién hizo qué y cuándo sobre documentos, comunicaciones, historias y catálogos. |
| Actor | Sistema / Administrador |
| Precondición | Usuarios y perfiles configurados. |
| Flujo principal | 1. Al iniciar sesión, el sistema determina perfil y dependencia. 2. En cada acción valida el permiso sobre la función y el recurso. 3. Registra usuario, acción, recurso, fecha y valores previos y nuevos. 4. El Administrador consulta y filtra el historial. |
| Flujos alternativos | Los intentos denegados se registran. La auditoría no se puede editar ni borrar. |
| Postcondición | Toda acción relevante queda trazada. |
| Prioridad | Alta |
| Origen | Primer audio de requisitos del cliente (Archivo Central) |

RF-AC-024 — Anular sin borrar
| Campo | Contenido |
|---|---|
| Identificador | RF-AC-024 |
| Nombre | Anular sin borrar |
| Descripción | Permitir anular documentos, comunicaciones o lotes registrados por error, indicando el motivo, sin borrarlos físicamente. |
| Actor | Archivo Central |
| Precondición | Registro existente; permiso de Archivo Central. |
| Flujo principal | 1. El usuario elige "Anular" e indica el motivo. 2. El sistema pide confirmación. 3. El registro pasa a "Anulado" y se oculta de las listas normales. |
| Flujos alternativos | Los anulados se consultan con un filtro específico. No existe borrado definitivo desde la interfaz. |
| Postcondición | Registro anulado con trazabilidad. |
| Prioridad | Media |
| Origen | Primer audio de requisitos del cliente (Archivo Central) |

## 3.1 Resumen de requisitos funcionales
| ID | Requisito | Actor principal | Prioridad |
|---|---|---|---|
| RF-AC-001 | Gestionar dependencias | Administrador | Alta |
| RF-AC-002 | Gestionar la Tabla de Retención Documental (TRD) | Administrador / Archivo Central | Alta |
| RF-AC-003 | Gestionar asuntos por dependencia | Archivo Central / Administrador | Alta |
| RF-AC-004 | Gestionar tipos documentales, programas académicos y ubicaciones físicas | Archivo Central / Administrador | Media |
| RF-AC-005 | Gestionar usuarios y perfiles | Administrador | Alta |
| RF-AC-006 | Gestionar parámetros y plantillas de correo | Administrador / Archivo Central | Media |
| RF-AC-007 | Centro de cargas y seguimiento de lotes | Archivo Central / Dependencia / Registro Académico | Alta |
| RF-AC-008 | Cargar un documento individual | Archivo Central | Alta |
| RF-AC-009 | Registrar una transferencia documental física | Archivo Central | Alta |
| RF-AC-010 | Registrar una transferencia documental digital | Dependencia / Archivo Central | Alta |
| RF-AC-011 | Clasificar documentos | Archivo Central | Alta |
| RF-AC-012 | Sugerir clasificación con inteligencia artificial | Archivo Central | Baja |
| RF-AC-013 | Navegar el archivo y consultar documentos clasificados | Archivo Central / Dependencia / Secretaría General | Alta |
| RF-AC-014 | Búsqueda avanzada | Archivo Central / Dependencia / Secretaría General | Alta |
| RF-AC-015 | Recibir y registrar comunicaciones por correo | Sistema (flujo F1) / Archivo Central | Alta |
| RF-AC-016 | Remitir a una dependencia y recibir su respuesta | Archivo Central / Sistema (flujos F1 y F2) | Alta |
| RF-AC-017 | Responder al remitente | Archivo Central / Sistema (flujo F3) | Alta |
| RF-AC-018 | Recordatorios y correos sin asociar | Sistema (flujo F4) / Archivo Central | Media |
| RF-AC-019 | Registro histórico de comunicaciones | Archivo Central / Secretaría General | Alta |
| RF-AC-020 | Gestionar historias académicas | Archivo Central / Registro Académico / Secretaría General | Alta |
| RF-AC-021 | Carga masiva de historias académicas | Archivo Central / Registro Académico | Alta |
| RF-AC-022 | Escanear y cargar desde el celular | Archivo Central | Media |
| RF-AC-023 | Controlar acceso y registrar auditoría | Sistema / Administrador | Alta |
| RF-AC-024 | Anular sin borrar | Archivo Central | Media |

# 4. Requisitos no funcionales
Organizados según las características de calidad de la ISO/IEC 25010.
| ID | Característica | Requisito | Métrica de verificación |
|---|---|---|---|
| RNF-AC-01 | Rendimiento | Búsquedas y listados deben responder rápido con miles de registros. | Respuesta < 3 s en búsquedas paginadas (20 por página) con 50.000 documentos (prueba de carga). Volumen tentativo. |
| RNF-AC-02 | Seguridad y privacidad | Proteger los datos personales de estudiantes y remitentes (Ley 1581 de 2012); comunicación cifrada (HTTPS); archivos no públicos. | 100% de accesos no autorizados denegados y auditados; descarga solo con sesión o enlace temporal. |
| RNF-AC-03 | Integridad | Cada archivo se verifica y no se duplica. | Hash SHA-256 por archivo; restricción única (expediente, hash); verificación semanal de hashes. |
| RNF-AC-04 | Confiabilidad del correo | Ningún correo se pierde ni se registra dos veces. | Message-ID único por comunicación; correo no marcado como leído hasta registrarse; 0 duplicados en prueba de reprocesamiento. |
| RNF-AC-05 | Oportunidad | Los correos entrantes deben aparecer pronto en la bandeja. | Registro en ≤ 5 minutos desde la llegada al buzón. |
| RNF-AC-06 | Capacidad y respaldo | El almacenamiento local del sistema debe soportar la migración de historias y respaldarse. | Capacidad para ~30.000 historias (estimado tentativo del orden de 600 GB, por confirmar); respaldo diario de base de datos y archivos, restauración probada. |
| RNF-AC-07 | Usabilidad | Un archivista debe cargar y clasificar sin capacitación extensa. | Carga + clasificación de un documento < 3 minutos en prueba con un usuario real. |
| RNF-AC-08 | Compatibilidad | Aceptar los formatos de digitalización y funcionar en celular. | PDF, JPG y PNG hasta 50 MB (tentativo); Excel .xlsx para inventarios; app en Chrome/Edge de escritorio y Chrome/Safari móvil. |
| RNF-AC-09 | Mantenibilidad | El módulo y sus flujos deben estar separados y documentados. | Módulo propio en backend y frontend; flujos n8n documentados; cobertura de pruebas ≥ 60% en consecutivos, estados y permisos. |
| RNF-AC-10 | Confiabilidad de la IA | La IA solo sugiere. | 100% de clasificaciones sugeridas requieren confirmación humana y quedan auditadas. |

# 5. Requisitos de interfaz
## 5.1 Interfaces de usuario
| Pantalla | Contenido |
|---|---|
| Inicio | Pendientes por clasificar, comunicaciones nuevas y vencidas, transferencias en proceso y dependencias que no han transferido este año. |
| Centro de cargas | Tarjetas por tipo de carga, asistente en 4 pasos y detalle de cada lote con avance e informe. |
| Transferencias | Lista por dependencia, año, tipo y estado; detalle con inventario por caja y acta adjunta. |
| Por clasificar / Clasificados | Lista con filtros; visor del PDF junto al formulario de tipo, consecutivo, fecha, caja, carpeta y asunto. |
| Archivo | Árbol Dependencia, Año, Asunto con contadores, listado y visor. |
| Buscar | Filtros por año, mes, dependencia, tipo, asunto, consecutivo y persona. |
| Comunicaciones | Bandeja con pestañas por estado, detalle con línea de pasos e historial, ventanas de remitir y responder, correos sin asociar e histórico en calendario. |
| Historias académicas | Árbol Estado, Año, Nivel, Programa; ficha del estudiante; carga masiva. |
| Catálogos | Lista con buscador, panel de edición, activar/inactivar, importar y exportar. |
| Auditoría | Tabla filtrable por usuario, acción, recurso y fecha. |
| App móvil | Inicio de sesión, escaneo multipágina, formulario y subida. |

▸ Las maquetas de estas pantallas deben validarse con la jefatura antes de iniciar el desarrollo.
## 5.2 Interfaces con otros sistemas
| Sistema | Uso |
|---|---|
| Supabase (PostgreSQL) | Tablas del módulo; funciones para consecutivos y cambios de estado; n8n escribe directamente. |
| Almacenamiento local del sistema | Guarda los archivos; n8n los envía al sistema por HTTP y recibe la ruta. |
| Correo institucional | Buzón de Archivo Central: lectura de correos entrantes y envío de remisiones, respuestas y recordatorios. |
| n8n | Flujos F1 a F11: correo entrante, remitir, responder, recordatorios, envío de correo, errores, inventario FUID, cargas digitales, historias, histórico e IA. |
| Servicio de IA | Sugerencia de asunto o dependencia a partir del contenido (opcional). |
| Archivos Excel | Importación de FUID, catálogos y registro histórico. |

# 6. Reglas de negocio
| ID | Regla |
|---|---|
| RN-AC-01 | El archivo se organiza en Dependencia, Año y Asunto. Cada documento pertenece a un solo asunto. |
| RN-AC-02 | El catálogo de asuntos se define por dependencia y cada asunto se vincula a un código TRD. |
| RN-AC-03 | Los documentos permanecen 2 años en el archivo de gestión. Cada año la dependencia transfiere hasta el año actual menos 2 (en 2026, hasta 2024). |
| RN-AC-04 | Los documentos se transfieren ordenados por serie, en orden cronológico, foliados y descritos. El inventario (FUID) y el acta los elabora la dependencia. |
| RN-AC-05 | En una transferencia física no se escanean los documentos: se guarda el inventario. En una digital se cargan todos los archivos. |
| RN-AC-06 | Las historias de estudiantes activos las gestiona Registro Académico; al graduarse o retirarse el estudiante, pasan a custodia de Archivo Central. |
| RN-AC-07 | Las historias académicas se organizan por Estado, Año, Nivel y Programa, con los estudiantes en orden alfabético. |
| RN-AC-08 | Las comunicaciones son de tipo entrada, salida o interno. Los consecutivos son secuenciales por tipo, reinician cada año y se generan con una función atómica de la base de datos. |
| RN-AC-09 | Estados de una comunicación: Nueva, Remitida, Respondida por dependencia, Devuelta (activas); Cerrada y Anulada (inactivas). Solo se cierra al enviar la respuesta al remitente. |
| RN-AC-10 | Los consecutivos históricos se adaptan al formato del sistema y se conserva el número original. |
| RN-AC-11 | Un archivo con el mismo hash dentro del mismo expediente es duplicado y no se registra. |
| RN-AC-12 | No hay borrado físico desde el sistema: solo anulación con motivo y auditoría. |
| RN-AC-13 | La IA nunca clasifica sola y no se aplica a historias académicas. |
| RN-AC-14 | Los archivos se guardan en el almacenamiento local del sistema; la base de datos (Supabase) solo guarda ruta, hash y metadatos. |

# 7. Historias de usuario
Total estimado del módulo: 121 puntos en 18 historias. La distribución por sprint e integrante se define en el F-04.
| ID | Historia | Requisitos | Prioridad | Puntos |
|---|---|---|---|---|
| HU-AC-01 | Como Administrador quiero gestionar dependencias, TRD y asuntos para que todo se clasifique con catálogos oficiales. | RF-AC-001, 002, 003 | Alta | 8 |
| HU-AC-02 | Como Archivo Central quiero mantener tipos documentales, programas y ubicaciones para usarlos al clasificar. | RF-AC-004 | Media | 3 |
| HU-AC-03 | Como Administrador quiero gestionar usuarios, parámetros y plantillas de correo. | RF-AC-005, 006 | Alta | 5 |
| HU-AC-04 | Como usuario quiero un centro de cargas con avance e informe para saber qué entró y qué falló. | RF-AC-007 | Alta | 8 |
| HU-AC-05 | Como Archivo Central quiero cargar un documento con su hash y detección de duplicados. | RF-AC-008 | Alta | 5 |
| HU-AC-06 | Como Archivo Central quiero registrar una transferencia física con el inventario de la dependencia. | RF-AC-009 | Alta | 8 |
| HU-AC-07 | Como dependencia quiero transferir mis documentos digitales con su inventario. | RF-AC-010 | Alta | 8 |
| HU-AC-08 | Como Archivo Central quiero clasificar los documentos pendientes, con ayuda opcional de la IA. | RF-AC-011, 012 | Alta | 8 |
| HU-AC-09 | Como usuario quiero navegar el archivo y buscar por año, mes, dependencia, tipo, asunto o persona. | RF-AC-013, 014 | Alta | 8 |
| HU-AC-10 | Como Archivo Central quiero que los correos que llegan se registren solos con su consecutivo y acuse. | RF-AC-015 | Alta | 8 |
| HU-AC-11 | Como Archivo Central quiero remitir a una dependencia y recibir su respuesta en el sistema. | RF-AC-016 | Alta | 8 |
| HU-AC-12 | Como Archivo Central quiero enviar la respuesta al estudiante y cerrar la comunicación. | RF-AC-017 | Alta | 5 |
| HU-AC-13 | Como Archivo Central quiero recordatorios automáticos y resolver correos sin asociar. | RF-AC-018 | Media | 5 |
| HU-AC-14 | Como Secretaría General quiero ver el histórico de comunicaciones por mes e importar los Excel antiguos. | RF-AC-019 | Alta | 5 |
| HU-AC-15 | Como Archivo Central quiero gestionar las historias académicas por estado, año, nivel y programa. | RF-AC-020 | Alta | 8 |
| HU-AC-16 | Como Archivo Central quiero migrar por carpetas las historias ya escaneadas. | RF-AC-021 | Alta | 8 |
| HU-AC-17 | Como Archivo Central quiero escanear y subir documentos desde el celular. | RF-AC-022 | Media | 8 |
| HU-AC-18 | Como Administrador quiero permisos por perfil, auditoría y anulación sin borrado. | RF-AC-023, 024 | Alta | 5 |

# 8. Matriz de trazabilidad
Se inicia aquí y se cierra en el documento de pruebas (F-05).
| Requisito | Historia de usuario | Componente que lo implementa | Caso de prueba |
|---|---|---|---|
| RF-AC-001 | HU-AC-01 | Catálogos (backend) + pantalla Dependencias | Crear dependencia con código o correo repetido y verificar rechazo |
| RF-AC-002 | HU-AC-01 | Módulo TRD + pantalla | Importar TRD con código duplicado y verificar reporte |
| RF-AC-003 | HU-AC-01 | Catálogos + pantalla Asuntos | Crear el mismo asunto en dos dependencias (válido) y en la misma (rechazo) |
| RF-AC-004 | HU-AC-02 | Catálogos de apoyo | Inactivar un tipo documental en uso y verificar que no se elimina |
| RF-AC-005 | HU-AC-03 | Usuarios y perfiles | Usuario inactivo no puede iniciar sesión |
| RF-AC-006 | HU-AC-03 | Parámetros + plantillas | Cambiar plantilla y verificar el siguiente correo enviado |
| RF-AC-007 | HU-AC-04 | Centro de cargas + lotes | Lote con un duplicado y un inválido; verificar informe y reintento |
| RF-AC-008 | HU-AC-05 | Servicio de carga + flujo F8 | Cargar el mismo PDF dos veces y verificar duplicado |
| RF-AC-009 | HU-AC-06 | Transferencias + flujo F7 | Inventario con año 2025 en 2026: aviso y bloqueo |
| RF-AC-010 | HU-AC-07 | Transferencias + flujos F7 y F8 | Transferencia digital: archivos asociados a su asunto |
| RF-AC-011 | HU-AC-08 | Clasificación + visor | Clasificar y verificar expediente, TRD y auditoría |
| RF-AC-012 | HU-AC-08 | Flujo F11 (IA) | Sugerencia aceptada, modificada y descartada, auditadas |
| RF-AC-013 | HU-AC-09 | Árbol de archivo + visor | Dependencia no ve carpetas de otra |
| RF-AC-014 | HU-AC-09 | Servicio de búsqueda | Buscar "385 del 29 de febrero" y por persona |
| RF-AC-015 | HU-AC-10 | Flujo F1 + bandeja | Mismo correo leído dos veces: una sola comunicación |
| RF-AC-016 | HU-AC-11 | Flujos F2 y F1 (rama respuesta) | Respuesta con etiqueta borrada se asocia por In-Reply-To |
| RF-AC-017 | HU-AC-12 | Flujo F3 | Envío fallido no cierra la comunicación |
| RF-AC-018 | HU-AC-13 | Flujo F4 + correos sin asociar | Una dependencia con 5 vencidas recibe un solo recordatorio |
| RF-AC-019 | HU-AC-14 | Histórico + flujo F10 | Importar el mismo Excel dos veces sin duplicar |
| RF-AC-020 | HU-AC-15 | Historias académicas | Registro Académico no ve historias de retirados |
| RF-AC-021 | HU-AC-16 | Flujo F9 + lotes | Carga por carpetas ordena alfabéticamente y agrega a historias existentes |
| RF-AC-022 | HU-AC-17 | PWA de escaneo | Escanear 3 páginas y subir desde el celular |
| RF-AC-023 | HU-AC-18 | Guard de perfiles + auditoría | Intento sin permiso denegado y auditado |
| RF-AC-024 | HU-AC-18 | Servicio de anulación | Anular y verificar que el registro sigue en la base |

# 9. Acta de validación y aprobación del cliente
Yo, en calidad de responsable designado por la dependencia solicitante, declaro que:
He revisado en su totalidad el presente documento de especificación de requisitos.
Los requisitos aquí consignados reflejan las necesidades reales de la dependencia.
Comprendo el alcance definido y lo que queda explícitamente excluido.
Autorizo al equipo de desarrollo a iniciar la construcción del software con base en esta especificación.
Entiendo que cualquier modificación posterior debe tramitarse mediante el control de cambios del numeral 10 y requiere nueva aprobación.
| Cliente Nombre: Cargo: Documento: Fecha: | Equipo de desarrollo Nombre: Fecha: |
|---|---|

# 10. Control de cambios
| Versión | Fecha | Descripción del cambio | Solicitado por | Aprobado por |
|---|---|---|---|---|
| 1.0 | 5 de octubre de 2026 | Versión inicial del F-02 del módulo Archivo Central. |  |  |
| 1.1 | 7 de octubre de 2026 | Se eliminan las historias laborales y el perfil Talento Humano. Se agregan: regla de 2 años y transferencias físicas (solo inventario y acta de la dependencia) y digitales; centro de cargas; historias académicas por estado, año, nivel y programa con carga masiva; circuito de comunicaciones por correo con estados y recordatorios; tipo de comunicación interno; app móvil de escaneo; catálogos de tipos documentales, programas, ubicaciones, parámetros y plantillas. Almacenamiento local del sistema y escritura directa de n8n en Supabase. |  |  |
