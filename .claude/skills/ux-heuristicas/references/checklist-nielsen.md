# Checklist de evaluación heurística (Nielsen)

Formato por ítem: **SÍ / NO / N/A + comentario**. ⚠ = ítem en negativo: lo correcto es **NO**.
Los ítems marcados con 📱 son complementos para móvil (no venían en la clase).

## H1. Visibilidad del estado del sistema
- [ ] El sistema indica la sección donde se encuentra el usuario.
- [ ] Informa el estado actual de un proceso o tarea.
- [ ] La transición de un estado a otro se percibe fácilmente.
- [ ] Los vínculos están claramente identificados y se diferencian del texto plano.
- [ ] Muestra claramente cómo reacciona a las acciones del usuario.
- [ ] Los tiempos de respuesta son razonables.
- [ ] La opción seleccionada se destaca claramente sobre las otras.
- [ ] 📱 El estado sin conexión o de sincronización es visible.

## H2. Coincidencia entre el sistema y el mundo real
- [ ] Usa palabras, frases y conceptos familiares para el usuario.
- [ ] La información es simple, natural y en orden lógico.
- [ ] Está diseñado en el idioma que indica.
- [ ] La secuencia de pasos sigue el modelo mental del usuario.
- [ ] Usa metáforas y controles que corresponden con la realidad.
- [ ] Las metáforas son fáciles de comprender.
- [ ] Los controles importantes están en pantalla.
- [ ] Explica los elementos complejos.

## H3. Control y libertad del usuario
- [ ] Es posible deshacer una acción que ejecuta una función u operación.
- [ ] En una transacción de varios pasos se puede volver a pasos anteriores para modificarlos.
- [ ] Existe una salida de emergencia (cancelar, desconectar, volver al inicio).
- [ ] No se inician automáticamente acciones que el usuario no eligió (por ejemplo, un video).
- [ ] Se puede guardar la información de una transacción, exitosa o no.
- [ ] Existe un vínculo para regresar al inicio.
- [ ] 📱 El botón/gesto "atrás" del sistema operativo funciona como se espera.

## H4. Consistencia y estándares
- [ ] Las etiquetas de los vínculos tienen el mismo nombre que las páginas a las que llevan.
- [ ] Las mismas acciones llevan a los mismos resultados.
- [ ] Los elementos son similares en todo el sistema.
- [ ] Los controles se usan siempre del mismo modo en todas las pantallas.
- [ ] El vocabulario es consistente.
- [ ] La misma información se muestra de la misma forma.
- [ ] La información está estructurada de forma similar.
- [ ] Las interfaces tienen un aspecto visual coherente.
- [ ] En situaciones similares se repiten las mismas secuencias de acciones.
- [ ] Los símbolos son comprensibles y facilitan la interacción.
- [ ] Se usan colores estándar (rojo = advertencia, verde = éxito).
- [ ] Se siguen los estándares de símbolos (X = cancelar, etc.).
- [ ] La barra de navegación, la búsqueda y los botones siguen las ubicaciones habituales.
- [ ] 📱 Respeta las guías de la plataforma (Material Design / Human Interface Guidelines).

## H5. Prevención de errores
- [ ] Pide confirmación antes de una acción crítica (cancelar, eliminar, aceptar).
- [ ] Ofrece mensajes fáciles de entender que previenen errores.
- [ ] Ofrece métodos de selección (listas de opciones) como alternativa a escribir.
- [ ] Los campos tienen valores por defecto cuando corresponde.
- [ ] Todos los datos de entrada se validan.
- [ ] 📱 Cada campo abre el teclado adecuado (numérico, email, teléfono).

## H6. Minimizar la carga de memoria
- [ ] Las opciones y funciones son fáciles de encontrar.
- [ ] Los controles principales están siempre disponibles, visibles y accesibles.
- [ ] Los campos ya llenados conservan la información.
- [ ] 📱 Las etiquetas de los campos siguen visibles mientras se escribe (no solo placeholder).

## H7. Flexibilidad y eficiencia de uso
- [ ] Existen atajos para las tareas frecuentes.
- [ ] El sistema es personalizable según las necesidades y preferencias del usuario.
- [ ] No pide de nuevo información ya ingresada.
- [ ] ⚠ Las acciones del usuario toman mucho tiempo.
- [ ] Informa si la ejecución de una acción va a tardar.
- [ ] Al llenar un campo, las opciones se pueden seleccionar sin escribirlas.
- [ ] La búsqueda es visible en todo el sistema.
- [ ] 📱 Todo gesto tiene una alternativa visible (botón o menú).

## H8. Diseño estético y minimalista
- [ ] La interfaz es simple.
- [ ] ⚠ Está sobrecargada de información, opciones o elementos que distraen.
- [ ] Las alternativas que el usuario necesita para una tarea están visibles.
- [ ] La información es simple, concisa y clara.
- [ ] La información visible es suficiente para actuar.
- [ ] ⚠ Hay iconos o elementos gráficos abstractos.
- [ ] ⚠ Hay iconos, controles, menús, gráficos o textos redundantes.
- [ ] ⚠ Hay elementos exclusivamente ornamentales.
- [ ] ⚠ Presenta información repetida.
- [ ] Los colores dan un contraste adecuado (WCAG AA: 4.5:1 en texto normal).
- [ ] Los elementos y secciones están bien distribuidos.
- [ ] 📱 Los objetivos táctiles miden al menos 44×44 pt (iOS) / 48×48 dp (Android).

## H9. Reconocer, diagnosticar y recuperarse de errores
- [ ] Los mensajes de error son comprensibles: lenguaje común, sin códigos ni tecnicismos.
- [ ] Indican la causa del error.
- [ ] Orientan al usuario para solucionarlo.
- [ ] Usan una terminología y un diseño consistentes.
- [ ] Son constructivos: no culpan ni ofenden al usuario.
- [ ] ⚠ Usan palabras violentas u hostiles.

## H10. Ayuda y documentación
- [ ] Ofrece una ayuda clara y simple.
- [ ] La ayuda está en el lenguaje del usuario, sin jergas.
- [ ] La ayuda es fácil de encontrar, entender y aplicar.
- [ ] La ayuda siempre está visible y disponible.
- [ ] La estructura de la ayuda se distingue fácilmente.
- [ ] Las instrucciones siguen la secuencia de acciones de la tarea.
- [ ] La interfaz de la ayuda es consistente con el resto del sistema.
- [ ] En la ayuda la información es fácil de encontrar.
- [ ] Existe ayuda contextual sobre los distintos elementos.

## Resumen

| Heurística | Cumple | Aplicables | % |
|---|---|---|---|
| H1 … H10 | | | |
| **Total** | | | |
