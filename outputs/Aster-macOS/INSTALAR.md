# Instalar Aster 0.6

Esta compilación es una **vista previa**. Tiene firma local de desarrollo; todavía no está firmada con Developer ID ni notarizada por Apple. No es la descarga pública definitiva.

1. Abre la imagen de disco y arrastra Aster a Aplicaciones.
2. Abre Aster. Si macOS bloquea la vista previa, espera a la versión con firma de Apple; no hace falta desactivar las protecciones del sistema.
3. En Ajustes → Conexiones, conecta tu cuenta de OpenAI. La clave queda en el Llavero de este Mac.
4. Activa individualmente las conexiones que quieras utilizar. Pantalla y Accesibilidad se autorizan en cada Mac.
5. Para pasar tus conversaciones desde otro Mac, usa Guardar copia en el original y Restaurar copia en el nuevo.
6. Para el iPhone, instala Aster Remote y escanea el código de Ajustes → Conexiones → Enlazar mi iPhone. Este paso requiere un Aster Relay publicado en Internet y su dirección `wss://`.

Requisitos: macOS 14 o posterior; Apple Silicon o Intel. El paquete contiene las dos arquitecturas. Las pruebas de ejecución se han hecho en Apple Silicon; Intel se ha compilado, pero no se ha probado en hardware Intel.

Aster necesita Internet y saldo en tu cuenta de OpenAI. El acceso desde el iPhone requiere el Mac encendido y Aster abierto. El control de pantalla requiere también que esté desbloqueado. Cerrar la ventana principal mantiene Aster en la barra de menús; Salir de Aster detiene el servicio.

Mientras habilitas el acceso remoto se evita el reposo por inactividad. No se evita el apagado, el reposo manual ni el cierre de la tapa. El control del ordenador se pausa si el iPhone se desconecta. Los chats de los agentes pueden seguir en el Mac.

El código de emparejamiento es privado. Desvincular iPhone lo invalida. El móvil no recibe tu clave de OpenAI y el servidor no recibe la clave de cifrado de tus conversaciones o capturas.
