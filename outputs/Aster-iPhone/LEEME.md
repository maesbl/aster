# Aster Remote para iPhone — 0.6

App nativa para iOS 17 o posterior. Permite conversar con los agentes del Mac, consultar sus tareas y empresas, seguir el resultado de una misión y abrir un panel de pantalla y control remoto.

## Abrir el proyecto

Mantén `Aster-iPhone` y `Aster-macOS` junto a la otra carpeta: el proyecto comparte los archivos de comunicación de `Aster-macOS/Shared`. Abre `AsterRemote.xcodeproj` en Xcode y elige el esquema AsterRemote. El proyecto público no contiene una cuenta de firma. Elige tu propio equipo y un identificador único en Signing & Capabilities; el generador admite ASTER_APPLE_TEAM y ASTER_IOS_BUNDLE_ID.

La compilación para un dispositivo real necesita un certificado con su clave privada y un perfil de aprovisionamiento. La compilación sin firma y la ejecución inicial en el simulador se han verificado. Eso no equivale a una instalación mediante TestFlight.

## Enlazar el Mac

1. Instala Aster en el Mac y conecta OpenAI desde Ajustes → Conexiones.
2. Configura un Aster Relay publicado con HTTPS/WebSocket seguro. La publicación en Vercel sigue pendiente de completar su integración de coordinación compartida.
3. En Aster, crea el enlace del iPhone y escanea su QR con Aster Remote. También puedes pegar el enlace privado.
4. La app guarda el enlace en el Llavero después de recibir una respuesta cifrada válida del Mac.
5. Para manejar el escritorio, activa expresamente Permitir controlar este Mac y concede Pantalla y Accesibilidad en macOS.

El móvil no necesita tu clave de OpenAI. Los mensajes y capturas se cifran entre los dispositivos; el servidor reenvía esos datos sin descifrarlos. No compartas el QR o enlace privado. Desvincular el iPhone desde el Mac invalida ese enlace.

## Qué esperar de esta vista previa

- Equipo: agentes, conversaciones, empresas y tareas recientes del Mac.
- Mi Mac: imágenes de la pantalla, instrucciones al agente, pausa, continuar y detener; control manual cuando no hay una tarea del ordenador en marcha.
- Actividad: órdenes y resultados confirmados por el Mac. Una interrupción no vuelve a enviar automáticamente una orden.
- La pantalla se solicita mientras está abierto ese panel; el objetivo actual es hasta unas cuatro imágenes por segundo, según captura y conexión. No es todavía vídeo de escritorio a 60 fps.
- Al dejar la app en segundo plano se cierra su conexión. Los agentes pueden seguir trabajando en el Mac, pero esta versión no incluye notificaciones push de iPhone.
- El Mac debe estar encendido y Aster abierto. Para ver y controlar la pantalla también debe estar desbloqueado. El enlace no enciende un Mac apagado ni evita el reposo al cerrar la tapa.

Antes de distribuir por TestFlight quedan por completar la firma, la ficha de App Store Connect y sus declaraciones de privacidad y cifrado, además de comprobar el enlace en un iPhone físico y desde una red distinta a la del Mac.
