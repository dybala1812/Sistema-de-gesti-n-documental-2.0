# Sistema de Diseno Frontend

## Direccion visual

EDUCALC XE debe sentirse como una plataforma EdTech universitaria: profesional, confiable, clara y moderna. La referencia visual se acerca a Coursera, Khan Academy, Platzi academico y campus virtual premium, pero con identidad simple de universidad.

La sensacion principal debe ser:

- orden;
- confianza academica;
- tecnologia accesible;
- aprendizaje guiado;
- calma para estudiantes con ansiedad matematica.

## Layout

### Navbar

- Fondo blanco limpio.
- Logo o marca a la izquierda.
- Navegacion horizontal en desktop.
- Estados activos claros.
- Espaciado amplio y legible.
- En mobile, priorizar menu compacto y tactil.

### Hero

- Debe comunicar rapidamente que es una plataforma educativa de Calculo I.
- Puede usar fondo azul intenso o gradiente azul oscuro.
- CTA principal en amarillo/dorado.
- Imagen humana real cuando sea posible, preferiblemente estudiantes o contexto academico.
- Mantener alto contraste entre texto y fondo.

### Secciones

- Usar contenedores con ancho maximo `1200px`.
- Mantener aire visual sin perder densidad academica.
- Alternar fondo blanco y gris claro para separar bloques.
- Evitar saturacion visual: cada seccion debe tener una accion o idea principal.

### Cards

- Usar cards para unidades, temas, videos y resultados.
- Fondo blanco, borde claro y sombra suave.
- Radio consistente entre `12px` y `20px` segun jerarquia.
- Hover sutil: elevacion pequena, sombra un poco mayor o cambio de color.
- Las cards de la estructura del curso deben tener icono animado visible, titulo, descripcion, cantidad de temas y accion de exploracion.

### Laboratorio grafico

- El laboratorio debe sentirse como una herramienta, no como una fila larga de controles.
- Orden recomendado: encabezado, ecuacion a resolver, parametros, botones de accion, grafica, resultado/resumen.
- La grafica debe mostrarse vacia antes de resolver con un mensaje claro.
- Al resolver, la grafica se carga y permite zoom para inspeccionar aproximaciones.
- Los valores de aproximacion deben existir como vista secundaria mediante boton, no como bloque obligatorio en la vista inicial.
- Para limites, diferenciar visualmente aproximacion por izquierda, aproximacion por derecha y punto objetivo.

## Tipografia

- Titulos: `Poppins`, fallback `Inter`, system-ui.
- Texto: `Inter`, system-ui.
- Titulos con peso 700-800.
- Texto de apoyo con peso regular y color gris azulado.
- Evitar bloques largos sin jerarquia: usar subtitulos, listas y ejemplos.

## Interacciones

- Botones primarios deben verse claramente clicables.
- Hover breve, sin animaciones exageradas.
- Transiciones de `0.2s` a `0.25s`.
- En laboratorios, los resultados deben aparecer cerca de la accion que los genera.
- Los errores deben explicar como corregir el input.
- El menu lateral de recursos en los temas debe hacer scroll suave a cada seccion de la pagina.

## Tono visual

Usar un estilo flat/corporate/EdTech:

- bordes redondeados;
- sombras suaves;
- gradientes leves;
- iconos matematicos o academicos;
- imagenes reales;
- alta legibilidad.

Evitar:

- estetica generica de landing sin relacion academica;
- paletas moradas o neon ajenas a la marca;
- exceso de decoracion;
- animaciones que distraigan del aprendizaje;
- interfaces que parezcan dashboard empresarial si la vista es de aprendizaje.
