# Aster Relay 0.6

Transporte WebSocket de mensajes y capturas cifrados entre Aster para Mac y Aster Remote para iPhone. El servidor no recibe la clave de cifrado ni la clave de OpenAI. Reenvía paquetes binarios; no almacena conversaciones, capturas ni órdenes pendientes.

## Estado de esta entrega

El servidor incluido está probado **como una única instancia persistente**. Conserva en memoria la conexión de los dos dispositivos y elimina las salas inactivas. **Todavía no debe publicarse como función de Vercel:** dos dispositivos pueden llegar a instancias distintas y perder el enlace. El proyecto `aster-relay` está creado en Vercel; falta activar la coordinación compartida, integrarla y probarla antes de publicar.

Vercel requiere que el titular acepte las condiciones de la integración Upstash antes de activarla. Se ha solicitado el plan gratuito con ampliaciones automáticas desactivadas; aún no se ha creado el recurso ni desplegado el servidor público.

## Prueba local

Requisitos: Node.js 24 y pnpm 11.19.0.

```sh
pnpm install --frozen-lockfile
pnpm test
pnpm start
```

Escucha en `127.0.0.1:8787` por defecto. `GET /health` indica si el proceso está disponible. `GET /v1/connect` acepta una actualización WebSocket con `Authorization: Bearer …`, `X-Aster-Room` y `X-Aster-Role: mac|phone`. El token se deriva del secreto de emparejamiento; no es ese secreto.

Los clientes de desarrollo permiten `ws://` exclusivamente en loopback. Las apps Release exigen `wss://`. Para una prueba en Internet sobre un servidor persistente se necesita terminación TLS, un solo proceso y protección de red adecuada; el Dockerfile es una base de ejecución, no un despliegue completo.

Las pruebas cubren emparejamiento, rechazo de credenciales distintas, aislamiento de salas, reenvío binario y ausencia de cola/repetición al reconectar. La suite Swift adicional comprueba cifrado, rechazo de paquetes alterados o repetidos, entrega real a los agentes del Mac y recuperación de confirmaciones.

No incluyas archivos `.env`, `.vercel`, claves de firma ni credenciales en una descarga pública. Para reproducir la prueba Swift local: inicia el relay y ejecuta `zsh ../Aster-macOS/test-remote.sh` desde esta carpeta. La prueba usa datos ficticios y no mueve el cursor.
