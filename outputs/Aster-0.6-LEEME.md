# Aster 0.6 — vista previa para Mac e iPhone

Fecha de comprobación: 1 de octubre de 2026.

## Archivos

- **Aster-0.6.0-preview-universal.dmg**: instalador de vista previa para Mac, con Apple Silicon e Intel. La firma todavía es local; falta la firma de distribución y notarización de Apple.
- **Aster.app**: la misma app nativa que contiene el instalador.
- **Aster-macOS**: código de Mac, recursos, pruebas e instrucciones de compilación y distribución.
- **Aster-iPhone**: app nativa Aster Remote y proyecto de Xcode; requiere iOS 17 o posterior.
- **Aster-Relay**: servidor WebSocket probado en una sola instancia local. La publicación en Vercel queda pendiente.
- **Aster-0.6.0-completo.zip**: paquete conjunto con el instalador, los tres proyectos y estas instrucciones. No incluye claves privadas, la clave de OpenAI ni tus conversaciones.

El archivo anterior `Aster-macOS.zip` corresponde a 0.5. La entrega nueva es el archivo con **0.6.0** en el nombre.

## Cambios principales

La conexión de OpenAI se configura desde la propia app y queda en el Llavero del Mac. El instalador contiene ambas arquitecturas y ya no depende de una ruta de credenciales de este ordenador. Puedes exportar y restaurar tu espacio de trabajo desde Ajustes; restaurarlo guarda antes una copia del estado existente y deja las rutinas importadas pausadas.

Aster Remote muestra los agentes, empresas y tareas del Mac. Permite conversar con cada agente y recibir su resultado, además de un panel de pantalla y control manual o mediante instrucciones al agente. Para controlar el escritorio hay que habilitarlo expresamente en Aster y conceder los permisos de macOS. El enlace del iPhone es privado, cifrado y revocable desde el Mac.

## Comprobaciones completadas

- Compilación universal de Mac y verificación de la firma local. Imagen de disco montada y verificada; el ejecutable contiene arm64 y x86_64.
- App de Mac abierta con la conexión de OpenAI válida y la clave trasladada al Llavero.
- Ocho grupos de pruebas de las funciones existentes aprobados.
- App de iPhone compilada para simulador y archivada para dispositivo sin firma; pantalla inicial ejecutada en el simulador de Xcode.
- Pruebas del enlace: emparejamiento, cifrado, paquetes alterados o repetidos, aislamiento de salas, órdenes duplicadas, reconexión y agentes inexistentes.
- Prueba real: una petición de un cliente Swift de prueba que representa al iPhone atravesó el relay local cifrada, llegó al almacén de tareas real del Mac, ejecutó una tarea ficticia con OpenAI y devolvió su resultado confirmado. La sesión de prueba se eliminó después. La prueba no leyó tus correos ni controló el escritorio.

## Pendiente antes de distribución pública

1. Sustituir el certificado de desarrollo de Apple cuya clave privada falta y terminar la firma de iPhone. La sustitución está autorizada; Xcode quedó detenido cuando se bloqueó el Mac.
2. Firmar y notarizar la descarga de Mac con Developer ID.
3. Activar la integración de coordinación compartida en Vercel, adaptar el relay y verificarlo en Internet. El proyecto está creado; Vercel exige la aceptación de las condiciones de Upstash por el titular antes de provisionar el recurso solicitado en plan gratuito, sin ampliaciones automáticas.
4. Completar la distribución de iPhone y comprobar el enlace en un dispositivo físico desde una red diferente. Todavía no está publicada en TestFlight o App Store.

## Límites actuales

El acceso desde fuera de casa aún no está activado. Las pruebas remotas completadas usan el servidor local. No confundas la compilación con una prueba de uso real en un iPhone fuera de casa.

El Mac debe permanecer encendido y Aster abierto. La pantalla necesita que el Mac esté desbloqueado. Se evita el reposo por inactividad mientras se habilita el enlace, pero no el apagado, reposo manual o cierre de la tapa.

El panel remoto de esta vista previa transmite capturas, con un objetivo de hasta unas cuatro por segundo según la conexión y la captura. Aún no es vídeo fluido a 60 fps. La app de iPhone desconecta al pasar a segundo plano y no incluye todavía notificaciones push. Los agentes del Mac pueden continuar sus tareas durante esa desconexión; el control del ordenador se pausa.

El soporte Intel se ha compilado, pero no se ha comprobado en hardware Intel. La nueva app de iPhone no incluye todavía integración automática con Salud; la importación manual de Salud de Mac se mantiene.

Para instalar el Mac consulta `Aster-macOS/INSTALAR.md`; para abrir el proyecto de iPhone y enlazarlo, consulta `Aster-iPhone/LEEME.md`.
