# Retomar Aster 0.6

Proyecto pausado por su propietario el 1 de octubre de 2026. El objetivo siguiente es una descarga normal para Mac y una app de iPhone que permita dirigir los agentes y controlar el Mac desde cualquier lugar.

## Punto verificado

- Mac: app nativa con seis especialistas, empresas, conversaciones, memoria, Mail/Calendario/Recordatorios, voces, compañeros flotantes y control del ordenador.
- 0.6 añade configuración de OpenAI en el Llavero, restauración del espacio de trabajo, enlace privado de iPhone, comunicación cifrada y control remoto opcional.
- Ejecutable universal arm64/x86_64 e imagen de disco verificados. Ejecución comprobada en Apple Silicon; Intel solamente compilado.
- Ocho grupos de pruebas existentes aprobados; suites adicionales de relay y protocolo remoto aprobadas.
- Prueba real aislada: cliente Swift de prueba → relay local → almacén real del Mac → OpenAI → resultado confirmado. Las órdenes duplicadas y las reconexiones no crearon una segunda misión. La sesión de prueba se eliminó después.
- iPhone: compilación de simulador y archivo Release sin firma correctos; pantalla inicial ejecutada en el simulador de Xcode. Falta el uso completo en un iPhone físico.

## Trabajo pendiente, en orden

1. Firma de iPhone. Xcode detectó certificados Apple Development sin clave privada. El propietario autorizó sustituir el certificado necesario, pero la acción no se completó antes de pausar. Revisar Xcode → Settings → Apple Accounts → equipo → Manage Certificates; no dar por revocado o creado ningún certificado. Elegir el equipo propio en el proyecto público.
2. Firma Developer ID y notarización de Mac. `release.sh` acepta `ASTER_DEVELOPER_ID` y `ASTER_NOTARY_PROFILE`, con un perfil de notaría guardado en el Llavero. La descarga incluida conserva firma local.
3. Servidor de Internet. Se creó `aster-relay` en Vercel, sin despliegue público. La activación de Upstash quedó esperando que el titular aceptara sus condiciones. La solicitud fue para plan gratuito y sin ampliaciones automáticas. No se creó Redis. Vercel admite WebSockets, pero las conexiones pueden llegar a instancias diferentes; usar coordinación compartida, probar ese caso y después publicar. Nunca desplegar el relay actual como si el transporte entre instancias estuviera resuelto.
4. Probar una conversación, órdenes confirmadas y pantalla/control entre un iPhone físico y el Mac en redes distintas; verificar desconexión, bloqueo, pausa y revocación del enlace.
5. Distribución mediante TestFlight/App Store Connect: ficha, firma, privacidad y declaración de cifrado. No hay una app publicada ni un IPA instalable firmado.
6. Mejorar la frecuencia del panel remoto y añadir notificaciones push de iPhone. Ahora se solicitan capturas a un máximo aproximado de cuatro por segundo y se desconecta el teléfono al pasar a segundo plano.

El Mac debe estar despierto y Aster abierto; ver/controlar su pantalla exige que esté desbloqueado. El acceso remoto no enciende un Mac apagado ni evita el reposo al cerrar la tapa. Las tareas de ordenador remotas se pausan al desconectar el móvil; los chats pueden continuar en el Mac.

## Pruebas locales

Iniciar `pnpm start` en `outputs/Aster-Relay`. Desde la raíz ejecutar `zsh outputs/Aster-macOS/test-remote.sh`. Esta prueba no necesita una clave real, usa datos ficticios y no mueve el cursor. Su variante con OpenAI acepta como argumento la ruta a un archivo privado de entorno; debe usarse únicamente con una clave propia y una cuenta con saldo.

Los scripts históricos de `archive/development-tools` son material de referencia y pueden necesitar adaptar rutas. La documentación 0.5 conserva las limitaciones verificadas entonces. Las conexiones directas Google OAuth siguen pendientes; el propietario decidió posponerlas. Salud en Mac se importa manualmente, sin sincronización continua con HealthKit.

## Protección de credenciales y limpieza local

No se han publicado archivos privados de entorno, credenciales de Vercel, material de firma, datos locales de Aster ni conversaciones. La API key del propietario fue excluida y se comprobaron los archivos publicados, los paquetes y los blobs del historial original antes de subirlos. La nueva historia pública empieza con este checkpoint, sin un commit que contenga la clave.

Al terminar la verificación de GitHub se retirará la copia de desarrollo del Mac mediante la Papelera, sin vaciarla automáticamente. Las credenciales de cuentas y del Llavero no forman parte del repositorio.
