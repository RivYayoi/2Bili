package tv.bili.data.danmaku

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import tv.bili.data.api.BiliHeaders
import tv.bili.domain.model.Danmaku
import java.io.ByteArrayOutputStream
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.net.http.WebSocket
import java.nio.ByteBuffer
import java.util.concurrent.CompletionStage
import java.util.zip.Inflater

actual class DanmakuSource {

    actual suspend fun history(cid: Long): List<Danmaku> = withContext(Dispatchers.IO) {
        val request = HttpRequest.newBuilder(
            URI.create("https://api.bilibili.com/x/v1/dm/list.so?oid=$cid"),
        )
            .header("User-Agent", BiliHeaders.UA)
            .header("Referer", BiliHeaders.REFERER)
            .GET()
            .build()

        val response = HttpClient.newHttpClient()
            .send(request, HttpResponse.BodyHandlers.ofByteArray())

        if (response.statusCode() != 200) {
            emptyList()
        } else {
            parseDanmakuXml(inflateToString(response.body()))
        }
    }

    actual fun live(cid: Long): Flow<Danmaku> = callbackFlow {
        val textBuffer = StringBuilder()
        val binaryBuffer = ByteArrayOutputStream()

        val listener = object : WebSocket.Listener {
            override fun onOpen(webSocket: WebSocket) {
                webSocket.sendBinary(packet(OP_AUTH, authPacket(cid).toByteArray()), true)
                webSocket.request(1)
            }

            override fun onText(
                webSocket: WebSocket,
                data: CharSequence,
                last: Boolean,
            ): CompletionStage<*>? {
                textBuffer.append(data)
                if (last) {
                    parseDanmakuJson(textBuffer.toString()).forEach { trySend(it) }
                    textBuffer.setLength(0)
                }
                webSocket.request(1)
                return null
            }

            override fun onBinary(
                webSocket: WebSocket,
                data: ByteBuffer,
                last: Boolean,
            ): CompletionStage<*>? {
                val chunk = ByteArray(data.remaining())
                data.get(chunk)
                binaryBuffer.write(chunk)
                if (last) {
                    parseFrames(binaryBuffer.toByteArray()).forEach { trySend(it) }
                    binaryBuffer.reset()
                }
                webSocket.request(1)
                return null
            }

            override fun onError(webSocket: WebSocket, error: Throwable) {
                close(error)
            }

            override fun onClose(
                webSocket: WebSocket,
                statusCode: Int,
                reason: String,
            ): CompletionStage<*>? {
                close()
                return null
            }
        }

        val socket = withContext(Dispatchers.IO) {
            HttpClient.newHttpClient()
                .newWebSocketBuilder()
                .buildAsync(URI.create(WS_URL), listener)
                .get()
        }

        val heartbeat = launch {
            while (isActive) {
                delay(HEARTBEAT_MS)
                runCatching {
                    withContext(Dispatchers.IO) {
                        socket.sendBinary(
                            packet(OP_HEARTBEAT, HEARTBEAT_BODY.toByteArray()),
                            true,
                        ).get()
                    }
                }
            }
        }

        awaitClose {
            heartbeat.cancel()
            socket.abort()
        }
    }
}

private const val WS_URL = "wss://broadcastlv.chat.bilibili.com/sub"
private const val HEARTBEAT_MS = 30_000L
private const val HEARTBEAT_BODY = "[object Object]"

/** Bilibili's websocket operations. */
private const val OP_HEARTBEAT = 2
private const val OP_NOTIFICATION = 5
private const val OP_AUTH = 7

/**
 * `protover = 2` means "zlib-compressed JSON", which keeps us away from
 * protobuf code generation while still matching what the real web client
 * negotiates. The server replies with binary frames, not text frames.
 */
private fun authPacket(cid: Long): String =
    """{"uid":0,"roomid":$cid,"protover":2,"platform":"web","type":2,"key":""}"""

/** Builds the 16-byte header + body packet used by the danmaku protocol. */
private fun packet(operation: Int, body: ByteArray): ByteBuffer {
    val total = HEADER_SIZE + body.size
    return ByteBuffer.allocate(total).apply {
        putInt(total) // packet length
        putShort(HEADER_SIZE.toShort()) // header length
        // Client packets always carry plain JSON; response compression is
        // negotiated by the "protover" field inside the auth body.
        putShort(1)
        putInt(operation)
        putInt(1) // sequence id
        put(body)
        flip()
    }
}

private const val HEADER_SIZE = 16

/**
 * Splits a websocket message into protocol frames. A frame with protover 2
 * contains one or more nested frames after inflation, so this recurses.
 */
private fun parseFrames(bytes: ByteArray): List<Danmaku> {
    val result = mutableListOf<Danmaku>()
    var offset = 0

    while (offset + HEADER_SIZE <= bytes.size) {
        val length = readInt(bytes, offset)
        val headerLength = readShort(bytes, offset + 4)
        val protover = readShort(bytes, offset + 6)
        val operation = readInt(bytes, offset + 8)

        if (length < HEADER_SIZE || offset + length > bytes.size) break

        val bodyStart = offset + headerLength
        val bodyEnd = offset + length
        if (headerLength >= HEADER_SIZE && bodyStart <= bodyEnd) {
            val body = bytes.copyOfRange(bodyStart, bodyEnd)
            when {
                protover == 2 -> result += parseFrames(inflateToBytes(body))
                protover == 0 && operation == OP_NOTIFICATION ->
                    result += parseDanmakuJson(body.toString(Charsets.UTF_8))
            }
        }

        offset += length
    }

    return result
}

private fun readInt(bytes: ByteArray, offset: Int): Int =
    ((bytes[offset].toInt() and 0xFF) shl 24) or
        ((bytes[offset + 1].toInt() and 0xFF) shl 16) or
        ((bytes[offset + 2].toInt() and 0xFF) shl 8) or
        (bytes[offset + 3].toInt() and 0xFF)

private fun readShort(bytes: ByteArray, offset: Int): Int =
    ((bytes[offset].toInt() and 0xFF) shl 8) or
        (bytes[offset + 1].toInt() and 0xFF)

private fun inflateToString(bytes: ByteArray): String {
    for (nowrap in listOf(false, true)) {
        val result = runCatching { inflateToBytes(bytes, nowrap).toString(Charsets.UTF_8) }
            .getOrNull()
        if (!result.isNullOrBlank()) return result
    }
    return bytes.toString(Charsets.UTF_8)
}

private fun inflateToBytes(bytes: ByteArray, nowrap: Boolean = false): ByteArray {
    val inflater = Inflater(nowrap)
    inflater.setInput(bytes)

    val out = ByteArrayOutputStream()
    val buffer = ByteArray(4096)
    while (!inflater.finished()) {
        val read = inflater.inflate(buffer)
        if (read == 0) {
            if (inflater.needsInput() || inflater.needsDictionary()) break
        } else {
            out.write(buffer, 0, read)
        }
    }
    inflater.end()
    return out.toByteArray()
}
