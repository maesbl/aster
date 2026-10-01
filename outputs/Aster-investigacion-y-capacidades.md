# Aster 0.5 · Compañero de trabajo y pantalla

Investigación: 30 de septiembre de 2026. Compilación: 1 de octubre de 2026. Esta comparación distingue las capacidades documentadas por otros productos de las implementadas y verificadas en Aster. No es una prueba de superioridad competitiva.

## Qué hemos aprendido

**Grok Bot** presenta compañeros persistentes, trabajo paralelo y un ordenador en la nube. Su continuidad no depende de mantener abierto el portátil. Además, diferencia instrucciones reutilizables —skills— de ejecuciones programadas —rutinas— con responsable e historial. Fuentes: [visión del producto](https://docs.x.ai/grok-bot/overview), [skills y rutinas](https://docs.x.ai/grok-bot/skills-routines-and-automations), [ordenadores y aplicaciones](https://docs.x.ai/grok-bot/computer-and-apps).

**ChatGPT Dots** combina una identidad persistente con memoria, tareas independientes, colaboración con agentes y trabajo en segundo plano. Sus controles distinguen conversaciones, tareas y seguimiento proactivo; su ordenador remoto y la conexión al Mac tienen condiciones diferentes. Fuentes: [Dots](https://learn.chatgpt.com/docs/dots), [tareas y memoria](https://learn.chatgpt.com/docs/dots/tasks-and-memory), [ordenadores y apps](https://learn.chatgpt.com/docs/dots/computers-and-apps), [controles](https://learn.chatgpt.com/docs/dots/controls).

**HeyClicky** combina ayuda sobre la pantalla, conversación y anotaciones visuales con ejecución de tareas. Su historial de cambios también documenta problemas causados por capas flotantes del cursor y una evolución hacia acciones dentro de aplicaciones. Esto aconseja mantener pequeñas las ventanas de compañía, separar dibujo de control y excluir las propias capas de la captura. Fuentes: [descripción oficial](https://www.heyclicky.com/about), [historial de cambios](https://www.heyclicky.com/changelog).

## Qué cambia en Aster 0.5

| Capacidad | Implementación en esta versión | Alcance |
|---|---|---|
| Varios agentes trabajando | Ejecuciones independientes, tres simultáneas por defecto; ajuste de uno a seis | Cada conversación tiene su propio flujo, cancelación, tiempo máximo e identidad de sesión |
| Continuidad | Conversaciones persistentes y contexto acotado de trabajos completados | Personal por agente; empresa por espacio. Respeta la opción de usar memoria |
| Actividad | Panel con estado de cada misión, acceso al resultado y detención individual | Mantiene el foco en lo que está haciendo el usuario |
| Rutinas | Responsable, espacio, instrucciones, hora y zona horaria, días laborables o todos los días | Planificación local; límite diario y descanso; historial de hasta treinta ejecuciones |
| Recuperación | Guarda la ejecución programada antes de enviarla; pausa si necesita revisión | Evita repetir automáticamente acciones con resultado incierto tras un cierre |
| Junto al cursor | Compañero pequeño que sigue el movimiento; se puede desactivar | La animación de desplazamiento se detiene cuando el puntero está quieto |
| Explicación visual | Pregunta y captura actual, respuesta de IA y marcas sobre la pantalla | Solo captura al pedir explicación; la captura se envía a OpenAI |
| Dibujar juntos | Trazo libre, flechas, círculos, rectángulos, deshacer y borrar | Capa temporal. Los trazos del usuario se incluyen como contexto en la siguiente explicación |
| Realizar trabajo en apps | Acceso al controlador del Mac existente; nueva acción de arrastre continuo | Puede escribir, usar atajos, abrir aplicaciones instaladas y arrastrar/dibujar en una app dentro de una tarea |
| Voz | Lectura de explicaciones mediante el sistema de voces ya integrado | No incorpora aún una llamada de voz bidireccional continua |

## Uso

Abre **Ordenador → A tu lado** o el menú **Ventana → A tu lado**. El atajo configurado es **⌥⌘K**. Elige el compañero, activa **Seguir cursor** si quieres acompañamiento y selecciona la aplicación de referencia cuando sea necesario.

- **Explicar**: pregunta sobre el contenido visible, pide una explicación de un ejercicio o un esquema. Las marcas son temporales y dejan pasar los clics.
- **Dibujar**: marca una zona, dibuja libremente o usa una forma. Pulsa **Listo / Esc** para volver a escribir y preguntar sobre tus trazos.
- **Hacer la tarea**: ejecuta la petición en las aplicaciones del Mac mediante el controlador visible. Los permisos de Pantalla y Accesibilidad deben estar concedidos. **Esc** detiene el control; una interacción del usuario pausa la tarea.
- **Actividad → Nueva rutina**: define instrucciones y horario. Se puede guardar pausada, ejecutarla manualmente y después activarla. Activar una rutina no equivale a activar todas las plantillas.

Las respuestas pueden contener errores: la explicación visual depende de que el contenido sea legible y de que la pantalla no cambie mientras llega la respuesta. No se promete precisión universal para cada aplicación o dibujo.

## Verificación

- Ocho grupos de pruebas automatizadas: protocolo de eventos, sesiones y archivos, almacenamiento, herramientas del Mac, conversaciones de escritorio, geometría, concurrencia, rutinas y validación de dibujos.
- Prueba real con OpenAI, usando datos ficticios: Atlas y Nova trabajaron simultáneamente en sesiones distintas; cada uno creó un archivo, comprobó su contenido y devolvió su marcador correcto. Ambos archivos se descargaron y las sesiones de prueba se eliminaron.
- Prueba real de visión con OpenAI y una imagen ficticia: identificó el botón «TOTAL» y devolvió un rectángulo con coordenadas normalizadas que lo encierra correctamente.
- Se abrió el panel nativo y funcionó el atajo dentro de Aster. La prueba inicial de explicación detectó una confusión entre la app activa y el panel; se añadió selección explícita de aplicación y corrección del contexto de captura.
- **Pendiente de verificación visual final:** el Mac se bloqueó antes de comprobar de nuevo la lectura de TextEdit, el seguimiento del cursor, el atajo desde otra app y los trazos manuales. La existencia del código y las pruebas de protocolo no sustituye esa comprobación.
- Firma local persistente, compilación nativa para Apple Silicon y conservación del identificador de la app. La actualización no modifica los permisos de macOS.

## Qué falta para competir al mismo nivel

1. **Servicio continuo fuera del Mac.** Las rutinas se inician con Aster abierto y el equipo despierto. Un turno ya enviado puede seguir en el entorno alojado, pero las herramientas locales dependen de la app. Esto no equivale a un servicio de Aster funcionando 24 horas con el Mac apagado.
2. **Voz bidireccional y guía con seguimiento de pasos.** Esta versión explica una captura y ejecuta tareas; no mantiene todavía una llamada en tiempo real ni verifica automáticamente cada clic de un alumno durante una lección.
3. **Integraciones completas.** Gmail, Drive y Google Calendar necesitan el registro OAuth que se dejó pendiente. Apple Health sigue siendo una importación, no una conexión de HealthKit en tiempo real. El acceso nativo a Mail, Calendario y Recordatorios depende de sus conexiones y permisos.
4. **Biblioteca de métodos aprendidos.** Las rutinas guardan instrucciones repetibles, pero aún no hay un editor de skills aprendidas por demostración con versiones y validación.
5. **Evaluación sostenida.** Para afirmar que Aster es mejor hacen falta pruebas comparables de éxito, tiempo, coste, consumo y recuperación en tareas reales de estudiantes y empresas.

La dirección del producto es un equipo personal y empresarial persistente, con compañía visual y trabajo verificable. Aster 0.5 refuerza esa base; no se presenta como una plataforma completa equivalente a esos productos.
