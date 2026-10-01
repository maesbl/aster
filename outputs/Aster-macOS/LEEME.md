# Aster para macOS · 0.6.0

Esta vista previa es nativa para **Apple Silicon e Intel, con macOS 14 o posterior**. Conserva tus personajes, conversaciones, empresas, memoria y preferencias de versiones anteriores. La app está firmada localmente y todavía no está notarizada para distribuirla a otros usuarios. Consulta **INSTALAR.md** antes de trasladarla a otro Mac; Intel se ha compilado, pero no probado en hardware real.

## Novedades de 0.6

La conexión de OpenAI se configura desde Ajustes → Conexiones y se guarda en el Llavero. Ya no depende de una ruta privada de este ordenador. Restaurar copia permite trasladar tu espacio desde otro Mac, con copia previa del estado actual y las rutinas importadas pausadas.

La app nativa **Aster Remote para iPhone** comparte los agentes, las empresas, las conversaciones y las tareas del Mac mediante un enlace cifrado. También incluye un panel de pantalla y control, que exige habilitarlo en el Mac. El QR de emparejamiento es privado y se puede revocar desde Aster.

La compilación y las pruebas locales de comunicación han pasado, incluida una orden cifrada que ejecutó una tarea real con OpenAI y devolvió su resultado. El servidor público de Vercel y la distribución de iPhone siguen pendientes; no se ha verificado aún el enlace de extremo a extremo desde un iPhone físico fuera de casa.

## A tu lado y trabajo independiente en 0.5

**Ordenador → A tu lado** abre el compañero de pantalla; también está en el menú Ventana, con el atajo **⌥⌘K**. El panel mide 340 × 470 puntos. Permite elegir compañero y aplicación de referencia, seguir el cursor, preguntar sobre la pantalla, escuchar la respuesta y pedirle trabajo en tus apps.

**Explicar** toma una captura al solicitarlo y la envía a OpenAI junto con la pregunta y los trazos que hayas añadido. La IA puede señalar controles, dibujar esquemas y explicar ejercicios con marcas temporales. **Dibujar** permite trazo libre, flechas, círculos y rectángulos, con deshacer y salida mediante Esc. Las marcas dejan pasar los clics fuera del modo de dibujo. No se guardan capturas en el historial local de este panel.

**Hacer la tarea** pasa la petición al controlador del Mac, con sus permisos, pausa por interacción del usuario y parada mediante Esc. Ahora admite arrastres y trazos continuos dentro de una aplicación. Las acciones se verifican con nuevas capturas; no se garantiza compatibilidad perfecta con todas las apps.

**Actividad** muestra las misiones en curso de forma independiente. Hay tres plazas simultáneas por defecto, configurables entre una y seis. Los minichats y la ventana principal pueden trabajar a la vez en conversaciones distintas. Cada misión conserva su estado, texto, sesión, tiempo máximo y cancelación.

**Rutinas** admite un responsable, espacio personal o empresa, instrucciones, hora, zona horaria y frecuencia diaria o laborable. Puedes guardar una rutina pausada, ejecutarla manualmente y activarla cuando te convenga. La app guarda la ejecución antes de enviarla y pausa la rutina ante un resultado incierto o un fallo. Se respetan el límite diario y las horas de descanso de Conexiones. Los resultados llegan a Bandeja y, si están activadas, a las notificaciones.

Las rutinas dependen de que **Aster esté abierto y el Mac despierto**. Tras una ausencia se ejecuta una sola vez cada rutina pendiente; no se repiten todos los intervalos perdidos. No hay aún un servidor de Aster que mantenga estas rutinas en marcha con el Mac apagado. La voz actual lee respuestas; todavía no es una llamada bidireccional en tiempo real.

### Verificación de esta entrega

Han pasado los ocho grupos de pruebas automatizadas, una prueba real de dos sesiones simultáneas con archivos independientes y una prueba real de visión con anotación correctamente situada en una imagen ficticia. El panel se abrió en macOS y el atajo funcionó dentro de Aster.

El Mac se bloqueó antes de completar la comprobación final del seguimiento del cursor, los trazos manuales, el atajo desde otra aplicación y la explicación sobre TextEdit tras corregir el cambio de foco. Esa comprobación queda pendiente; no debe confundirse con los resultados ya verificados del motor y la API.

## Equipo desplegable y minichat en 0.4.3

La flecha situada encima de los compañeros recoge todo el equipo. Púlsala de nuevo para desplegarlo. El plegado se conserva al reiniciar; las posiciones y los compañeros ocultos por separado se mantienen. Mostrar compañeros recupera todo el equipo y Ordenar arriba a la derecha vuelve a colocar la columna debajo de la flecha.

El equipo aparece y se recoge con una secuencia breve de deslizamiento y opacidad; la flecha gira con una transición suave. Estas animaciones no modifican las posiciones guardadas. Si vuelves a pulsar durante una transición, se cancela el cierre anterior. Reducir movimiento en macOS evita estos desplazamientos.

Pasa el cursor por un compañero durante un instante para abrir su minichat compacto de **320 × 390 puntos**. Aparece y desaparece con un pequeño deslizamiento y una transición de opacidad. Al cambiar de agente, el panel se desplaza suavemente hasta su nueva posición. Aparece junto al personaje, dentro de su pantalla, y permite entrar con el puntero sin cerrarse durante el recorrido. Mostrar esta vista no envía un mensaje ni inicia una generación de IA. La ventana de trabajo conserva el foco hasta que haces clic para escribir.

- Un clic en el compañero abre y fija su chat para escribir; arrastrarlo sigue moviéndolo. Doble clic abre su conversación en la ventana completa.
- La chincheta fija o suelta el minichat. Al escribir o enviar se fija para proteger la conversación; puedes cambiar de agente con un clic sobre el otro compañero.
- Cada agente conserva su propia conversación y su propio borrador. Cerrar el panel o cambiar de agente no los elimina.
- **Intro** envía; **Mayúsculas + Intro** introduce una línea; **Esc** cierra y conserva el borrador. La composición de texto de otros idiomas se respeta.
- **+** inicia una conversación nueva sin borrar la anterior de Misiones. La flecha diagonal abre el historial completo y sus archivos.
- Las respuestas llegan en directo. Puedes seleccionar texto, copiar la respuesta y escucharla con la voz del personaje. Si lees mensajes anteriores, Ir al último mensaje vuelve al final.
- Durante una respuesta aparece Detener. Cerrar o plegar el panel no cancela el trabajo ya iniciado.
- Si se alcanza el límite de trabajos simultáneos, el minichat conserva tu borrador y muestra el motivo de la espera. Otras conversaciones pueden seguir trabajando dentro del límite de Actividad; una misma conversación procesa un turno a la vez.
- Si una sesión necesita recuperación, el panel ofrece Recuperar antes de permitir otro envío.

**Ventana → Chat rápido** abre el chat del compañero seleccionado. **Hablar con…** permite elegir cualquiera de los seis. Con Aster activa, **⌥⌘J** abre el minichat y **⌥⌘B** pliega o despliega el equipo. Estas acciones también están disponibles en la barra de menús.

El minichat usa el mismo motor, memoria, personalidad, voces y herramientas conectadas de Aster. Mail, Calendarios y Recordatorios siguen necesitando sus conexiones. Para tareas de control del Mac, abre Ordenador: el minichat no afirma haber movido el cursor desde una sesión alojada.

## Escritorio e icono en 0.4.2

Los seis compañeros aparecen en una columna compacta en la esquina superior derecha del área útil de la pantalla, debajo de la barra de menús. Cada ventana mide 94 × 96 puntos y el personaje usa un lienzo de 64 puntos; en pantallas bajas la columna reduce su altura para que quepa completa. El tamaño del escritorio es independiente del tamaño de la vista principal y conserva la forma, el color y los efectos que hayas elegido.

- Arrastra el personaje, su nombre o la pequeña línea inferior para moverlo.
- Doble clic abre Aster con ese compañero seleccionado.
- Clic derecho permite abrir Aster, ordenar todo el equipo arriba a la derecha u ocultar ese compañero.
- **Ventana → Mostrar compañeros** y el botón **En tu escritorio** recuperan los compañeros ocultos.
- **Ventana → Ordenar arriba a la derecha** restablece la columna. Las mismas opciones están en el menú de Aster de la barra de menús.

La posición y el estado oculto se guardan por personaje y se recuperan al reiniciar. Si desaparece un monitor, los compañeros se devuelven al área visible. Durante el control del ordenador se ocultan para no cubrir la app de trabajo y al terminar vuelven los que estaban visibles.

El personaje seleccionado o que trabaja mantiene la animación de escritorio con un objetivo de 30 Hz; los demás solo se animan al pasar el puntero. Se respetan Reducir movimiento y la pausa de ventanas ocultas. La vista principal conserva su animación habitual.

El icono nuevo usa un compañero blanco sobre negro con una pequeña estrella. Se incluye en todas las resoluciones del paquete y Aster lo establece al arrancar para el Dock. La ventana **Acerca de Aster** muestra el mismo logo y la versión. La actualización conserva la identidad local de firma de 0.4.1.

## Corrección de permisos en 0.4.1

La firma anterior era ad hoc: su identidad dependía del hash de una compilación concreta. macOS podía conservar una entrada «Aster» activada en Ajustes que no autorizaba el ejecutable nuevo. La versión 0.4.1 usa un certificado local persistente y exige tanto su certificado como el identificador de Aster. No modifica la confianza del sistema ni concede permisos automáticamente.

Si los interruptores están activados pero Ordenador sigue mostrando los permisos pendientes:

1. Cierra Aster completamente con **⌘Q**.
2. En **Ajustes del Sistema → Privacidad y seguridad**, elimina la entrada antigua de Aster con **−** en el apartado de control/Accesibilidad y en Pantalla si el sistema permite quitarla.
3. Añade con **+** la copia de **Aster.app** que está junto a esta carpeta y permite su acceso. Si Pantalla solo ofrece un interruptor, desactívalo y vuelve a activar la copia actual cuando macOS la registre.
4. Abre esa misma Aster.app de nuevo. Si macOS pide salir y reabrir, acepta el reinicio. En Ordenador pulsa **Comprobar permisos**.

**Mostrar esta copia** abre Finder con la aplicación que está ejecutándose seleccionada. La página muestra su ruta para evitar autorizar otra copia con el mismo nombre. Los permisos también se comprueban cada dos segundos mientras esta página está abierta, sin sustituir la respuesta real de macOS por el estado del interruptor.

En la versión de macOS usada en esta prueba, el apartado de control se llama **Device Control and Data Access**. Selecciona la fila de Aster para habilitar el botón Remove; no selecciones ChatGPT, Codex ni otras apps.

La primera transición desde la firma antigua puede requerir esta renovación. Las futuras compilaciones deben conservar la identidad local de firma; una actualización firmada con otra identidad necesita una nueva autorización.

## Qué cambia

- Interfaz en negro, blanco y grises; los personajes conservan sus colores y personalidad.
- Fondo estático y superficies de lectura ligeras. El guardado se agrupa en segundo plano; las actualizaciones del chat se limitan para mantener la interfaz disponible.
- Personajes principales con animación objetivo de 60 Hz, miniaturas que se animan al pasar el puntero y pausa de animación cuando una ventana queda oculta. La frecuencia objetivo no equivale a una medición garantizada de FPS.
- **Atlas**, el sexto compañero, para estudiar, explicar, trabajar con documentos y usar apps del Mac.
- Herramientas reales del chat para Apple Mail, Calendarios, Recordatorios, avisos y datos importados de Salud.
- La vista apagada ya distingue «Ver pantalla» de un permiso pendiente. La entrada de texto limpia los modificadores de los atajos anteriores y separa la escritura de los saltos de línea y tabulaciones.
- **Ordenador**: pantalla en directo, movimientos de cursor, clics, escritura, atajos, desplazamiento y apertura de apps, con explicación visible de cada paso.
- **Voces**: trece voces naturales de OpenAI, elección por personaje y voces de macOS. La voz detecta el idioma del texto; las respuestas pueden seguir el idioma de tu mensaje.
- Tareas separadas en **Aster**, **Apple** y **Avisos**.
- Interfaz en español, inglés y catalán. La conversación puede usar otros idiomas.

En macOS 26 o posterior los controles usan Liquid Glass nativo. En sistemas anteriores usan los materiales compatibles del sistema. Reducir movimiento y Reducir transparencia se respetan automáticamente.

## Tu equipo

**Aster** coordina. **Milo** trabaja en marketing, **Nova** en desarrollo, **Sage** en negocio, **Lumi** en prioridades personales y creatividad, y **Atlas** en aprendizaje y trabajo con apps. Puedes cambiar nombre, personalidad, forma, color, tamaño, movimiento y efectos de cada personaje.

En Empresas, añade un nombre, objetivo y contexto; después pide una estrategia, investigación, plan, contenido, código o archivos. Los agentes usan sesiones de OpenAI, búsqueda cuando está habilitada y un entorno alojado donde pueden crear y comprobar entregables. Aster puede coordinar especialistas independientes. El modelo, profundidad, tono, detalle, memoria, idioma, número de especialistas y tiempo máximo se ajustan en Conexiones → Inteligencia.

Crear una empresa en Aster organiza un proyecto. La constitución legal, pagos, publicación y envío de comunicaciones requieren herramientas y autorización para la acción concreta.

## Correo que el chat puede leer

En **Conexiones → Conexiones → Apple Mail**, pulsa **Conectar Apple Mail** o **Comprobar Mail**. Acepta el acceso de macOS si te lo pide. Debes tener la cuenta añadida a la aplicación Mail del Mac; puede ser Gmail, iCloud, Outlook u otra cuenta que Mail admita.

Después puedes pedir:

- «Lee mi último correo y resume lo importante».
- «Busca los correos de Ana sobre la reunión».
- «Abre ese correo y dime qué tengo que hacer».

La herramienta obtiene el mensaje real y su contenido. El último correo se elige por fecha de recepción e incluye los mensajes ya leídos. La revisión periódica sigue usando asuntos y remitentes de correos sin leer para los avisos de la bandeja. La lectura no envía correo.

**Causa del problema anterior:** el chat no tenía una herramienta de lectura del mensaje, aunque Mail estuviera conectado para generar avisos. Esa herramienta está incorporada en esta versión. Si una conversación antigua conservaba otra configuración, Aster abre una sesión con las nuevas herramientas al continuarla.

Los resúmenes periódicos permanecen locales salvo que actives Compartir resúmenes. Cuando pides consultar una fuente desde la conversación, el contenido solicitado de la herramienta se envía a OpenAI para elaborar la respuesta.

## Calendarios y Recordatorios de Apple

Conecta cada fuente por separado en Conexiones. **Calendarios de macOS** permite leer citas de las cuentas añadidas al Mac, incluidas iCloud, Google y Outlook. **Recordatorios de Apple** permite consultar tus listas, crear recordatorios con notas y fecha y marcar tareas terminadas.

Pide «crea un recordatorio para entregar el trabajo mañana a las 9» o «qué tengo pendiente en Recordatorios». En **Tareas → Apple** puedes actualizar y completar recordatorios directamente. La app comprueba el permiso antes de consultar la fuente y muestra un error concreto cuando falta.

## Avisos que llegan a la hora elegida

Activa **Notificaciones** en Conexiones. Pide «recuérdame mañana a las 9 que entregue el trabajo» o crea un aviso en **Tareas → Avisos**. Puedes elegir una sola vez, cada día o cada semana, revisar lo guardado y cancelar un aviso.

La solicitud se registra en el sistema de notificaciones de macOS. Los avisos programados pueden entregarse con la ventana cerrada e incluso después de salir de Aster, de acuerdo con el estado del Mac y los ajustes de notificaciones y Concentración. Si el permiso falta, el aviso queda identificado como pendiente y Aster no afirma haberlo programado. Al permitir avisos se activan los pendientes que siguen vigentes.

## Ordenador: mirar y actuar

1. Abre **Ordenador**.
2. Permite **Pantalla** y **Accesibilidad** para Aster en Ajustes del Sistema → Privacidad y seguridad. Pantalla permite capturar lo visible; Accesibilidad permite escribir, mover el cursor y leer etiquetas de controles. macOS puede pedir reiniciar Aster.
3. Elige la pantalla y el compañero. Abre la app o documento con el que quieras trabajar.
4. Escribe una tarea concreta y pulsa **Empezar en mi Mac**.

Por ejemplo: «En el Excel que tengo abierto, completa las fórmulas de la columna Total, comprueba los resultados y explícame lo que haces».

Aster oculta su ventana principal, vuelve a la app de trabajo y muestra un panel compacto con el paso actual, Pausar y Detener. La pantalla se captura con ScreenCaptureKit; la vista local se actualiza hasta 12 veces por segundo. La IA recibe una captura nueva después de cada acción. La aplicación convierte las coordenadas de la imagen a coordenadas reales del monitor, incluidas pantallas Retina y monitores situados a la izquierda del principal.

Durante esa tarea, las capturas y etiquetas de controles se envían a OpenAI para decidir el siguiente paso. No se mantiene una sesión de control activa por defecto. El modelo seleccionado en Inteligencia también se usa para esta función.

**Esc detiene el control.** Si usas tú el teclado, haces clic o desplazas la pantalla, Aster pausa la tarea. Puedes responder a una pregunta, hacer tú un paso pendiente y continuar. También puedes detenerlo desde el panel o la página Ordenador. El historial de pasos y el resultado se conservan en Tus últimas tareas en el Mac y en la bandeja.

Las acciones se ejecutan de una en una y el resultado se revisa en la captura siguiente. Hay un límite de 60 pasos por tarea y el tiempo máximo configurado en Inteligencia. La app rechaza coordenadas fuera de pantalla y combinaciones de teclas no admitidas. Un acceso, permiso, pago, envío, contrato o borrado irreversible se deja para intervención del usuario. El motor no tiene una herramienta de terminal.

Una app o documento complejo puede necesitar más de una tarea. Comprueba el resultado antes de darlo por válido o entregarlo; una tarea completada por la IA no garantiza que cualquier interfaz o hoja de cálculo se haya entendido correctamente.

## Voces

En **Conexiones → Voces**, elige **Natural · OpenAI** o **Voces de macOS**. Las voces naturales —Marin, Cedar, Coral, Sage, Ash, Ballad, Alloy, Echo, Fable, Nova, Onyx, Shimmer y Verse— se pueden asignar a cada personaje y escuchar con el botón de prueba. Son voces generadas por IA y usan el saldo de OpenAI.

El botón de altavoz de cada respuesta lee el texto. La lectura detecta el idioma del mensaje o usa el idioma de respuestas que has elegido. Omite los bloques de código, lee las etiquetas de los enlaces y divide textos largos en fragmentos para preparar el siguiente audio mientras reproduce el actual. Puedes detenerla en cualquier momento.

La explicación de pasos durante el control usa las voces de macOS para empezar sin esperar a generar audio. Puedes desactivarla y seguir leyendo los pasos en pantalla. La calidad y disponibilidad de una voz en cada idioma dependen del proveedor o de las voces instaladas en macOS; no se han probado todos los idiomas.

## Gmail, Drive, Google Calendar y Salud

**Gmail y Google Calendar** funcionan a través de Mail y Calendario si ya tienes esas cuentas configuradas en macOS. La conexión directa mediante OAuth de Gmail, Drive y Calendar está pendiente de la configuración de Google que has decidido dejar para más adelante.

**Apple Salud** no permite leer datos de HealthKit directamente desde macOS. Esta versión incorpora una importación: en el iPhone abre Salud → perfil → Exportar todos los datos de salud, extrae el archivo y elige **export.xml** con Importar Apple Salud en Aster.

La importación conserva la última medición individual de los tipos admitidos, unidad, fecha y fuente. Muestra cuándo la importaste. No convierte una medición en un total diario ni pretende ser una conexión en directo. Puedes preguntarle a Aster por los registros importados y eliminarlos desde Conexiones. Una actualización continua de Salud necesitaría una app compañera para iPhone.

## Memoria, tareas y autonomía

Puedes añadir, editar y eliminar recuerdos personales o de empresa en Memoria. Los recuerdos de empresa se incluyen únicamente en su contexto. Recordar cuando se lo pida habilita el guardado solicitado desde el chat. Tareas conserva próximos pasos por empresa, fecha y especialista; Trabajar en ello abre una misión.

Autonomía permite elegir empresa o rotación, frecuencia, máximo de misiones al día, objetivo y horas de descanso. Cuando termina trabajo útil, Aster te escribe en la bandeja y puede avisarte. Las revisiones sin novedades permanecen silenciosas; una misión fallida pausa el trabajo autónomo para que revises el motivo.

**Iniciar trabajo nuevo y revisar fuentes localmente requiere Aster abierto y el Mac despierto.** Cerrar la ventana deja Aster en la barra de menús. Los agentes remotos ya iniciados pueden continuar en OpenAI; las herramientas locales esperan a que la app esté disponible. Iniciar nuevas misiones y revisar cuentas 24 horas con el Mac apagado sigue necesitando un servicio continuo en la nube, que no está conectado en esta versión. Los avisos con hora ya registrados en macOS usan su programación propia.

## Continuidad y archivos

Cada misión conserva sesión y turno. Si se corta la conexión, pulsa **Recuperar estado** antes de reenviar la instrucción. Detener solicita la cancelación remota; la app conserva el estado necesario para comprobarla. Si cambias herramientas, personalidad o configuración, el historial local se conserva y se abre una sesión con la nueva configuración cuando hace falta.

Los archivos de salida de las misiones se muestran como entregables descargables. Los adjuntos están limitados a diez archivos y 10 MB por envío. Puedes renombrar, fijar, archivar y restaurar misiones y empresas, exportar una conversación y guardar una copia del espacio de trabajo.

Los datos se guardan de forma atómica en `~/Library/Application Support/Aster/state.json`, con permisos locales restringidos. La clave de OpenAI se guarda en el Llavero de macOS y no se incluye en el código ni en el paquete. Para mover Aster a otro Mac, configura allí la conexión desde Ajustes → Conexiones e importa una copia del espacio si quieres conservar tus conversaciones.

## Verificación de esta versión

- En 0.4.3 se comprobó el panel real de 320 × 390 puntos: Milo respondió desde OpenAI con el marcador solicitado, Intro envió el mensaje al minichat, y Atlas mantuvo su borrador mientras Milo trabajaba. Se comprobaron acentos, Mayúsculas + Intro, cerrar y reabrir, cinco pulsaciones seguidas de plegado/despliegue y un reinicio. Las seis posiciones guardadas permanecieron exactamente iguales, el plegado persistió y el borrador de dos líneas reapareció. Pantalla y Accesibilidad siguieron disponibles. Se incluyen capturas del panel y de la respuesta real.
- La prueba real corrigió una configuración inválida que impedía iniciar conversaciones con los especialistas individuales. La suite de API comprueba ahora los seis personajes y el coordinador con delegación desactivada. También se conserva el foco del chat fijado al volver a activar Aster y se evitan guardados de borradores vacíos sin cambios.
- Compilación nativa optimizada y firma local correctas. En 0.4.2 se revisó el logo real en Acerca de Aster, las opciones de ordenar, ocultar y recuperar el equipo, y las seis posiciones de 94 × 96 puntos conservadas al reabrir la app. Ordenador siguió reconociendo sus permisos tras la actualización. La herramienta de comprobación no pudo completar de forma fiable un arrastre real sobre las ventanas flotantes; esa interacción no está certificada por las pruebas automatizadas.
- Siete suites: disposición del escritorio, protocolo de eventos, continuidad y datos, API y recuperación, control visual y cancelación, conexiones/avisos/Salud, y minichat. La prueba de disposición comprueba seis compañeros sin solaparse, pantallas pequeñas, coordenadas negativas de monitores, conservación de posiciones manuales y recuperación al desconectar un monitor. También cubre el espacio de la flecha y la colocación del minichat sin cubrir el compañero. La prueba de minichat verifica la separación de agentes, borradores e historial, la persistencia, el aislamiento de la ventana grande y sus adjuntos, la recuperación y los errores de conexión sin usar la red.
- Misión real de OpenAI completada con dos especialistas, respuesta en catalán, archivo adjunto leído y comprobado, tarea local guardada y archivo de salida descargado y verificado. Sesión de prueba eliminada.
- Voz natural Marin generada y MP3 decodificado correctamente: muestra de 11,16 segundos incluida junto a la app.
- Modelo real `gpt-6-luna` identificó el botón correcto de una imagen de prueba usando el mismo esquema de acciones del control del Mac.
- Revisión visual de la interfaz nueva y de la página Ordenador. Después de renovar las entradas antiguas, la app reconoció Pantalla y Accesibilidad y abrió la vista en directo. Atlas completó una tarea real de TextEdit, reemplazó dos líneas, guardó el mismo archivo y comprobó la pantalla. La inspección independiente del archivo guardado confirmó el contenido exacto. Después de una actualización, ambos permisos permanecieron concedidos.
- Las pruebas automatizadas de Mail, Calendarios y Recordatorios comprueban los permisos y los errores sin consultar datos personales. La lectura de fuentes reales necesita sus conexiones de macOS.

La primera prueba real de TextEdit se completó y requirió una corrección visual del texto. Después se ajustó la entrada de texto entre atajos, saltos de línea y tabulaciones; la segunda pasada nativa de ese ajuste queda pendiente de disponer del Mac libre.

No se ha medido una tasa de FPS garantizada. El control real en Excel, la recepción de una notificación con la app cerrada, todos los idiomas y la autonomía continua en la nube no están certificados por estas pruebas.

La comprobación nativa del minichat usó el atajo y el menú de agentes. La herramienta de comprobación no ofrece una acción de pasar el cursor sin pulsar; la apertura automática al pasar el cursor no tiene una prueba nativa automatizada. Las transiciones usan opacidad y transformaciones de la capa visual, con cancelación de cierres anteriores y respeto a Reducir movimiento, sin modificar la geometría guardada de los compañeros.

Se verificó que dos variantes con hashes distintos y la misma firma local satisfacen el mismo requisito de identidad de macOS. La app también siguió detectando ambos permisos después de la actualización usada en esta prueba. La firma anterior no cumplía la condición de identidad estable.

## Construcción

Con Xcode instalado, cierra Aster y ejecuta `zsh build.sh` en esta carpeta para generar Aster.app. `sign-local.py` conserva una identidad de desarrollo en `.aster-signing`, dos carpetas por encima del código. No borres esa carpeta si quieres que macOS reconozca futuras compilaciones. Su llavero privado queda bloqueado al terminar; la carpeta no se incluye en el paquete ni en el código distribuido. No se instala una raíz de confianza en el sistema. En otro Mac o en una carpeta nueva se creará otra identidad local y hará falta autorizarla. Para comprobar la lógica y el protocolo, ejecuta `zsh test.sh`. Las pruebas usan fuentes y respuestas aisladas; no necesitan tu clave ni mueven el cursor real.

Atajos: **⌘,** abre Ajustes; **⌘N** crea una misión nueva; **⌘L** enfoca el mensaje; **⌘W** cierra la ventana; **⌘M** la minimiza. Cada compañero del escritorio se puede arrastrar; doble clic abre la app con ese personaje y clic derecho permite ordenar la columna u ocultarlo.
