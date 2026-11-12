package tv.bili.data.danmaku

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import okio.ByteString.Companion.toByteString
import tv.bili.data.api.BiliHeaders
import tv.bili.domain.model.Danmaku
import java.io.ByteArrayOutputStream
import java.util.zip.Inflater

actual class DanmakuSource {

    actual suspend fun history(cid: Long): List<Danmaku> = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("https://api.bilibili.com/x/v1/dm/list.so?oid=$cid")
            .header("User-Agent", BiliHeaders.UA)
            .header("Referer", BiliHeaders.REFERER)
            .build()

        runCatching {
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@use emptyList()
                val bytes = response.body?.bytes() ?: ByteArray(0)
                parseDanmakuXml(inflateToString(bytes))
            }
        }.getOrDefault(emptyList())
    }

    actual fun live(cid: Long): Flow<Danmaku> = callbackFlow {
        val request = Request.Builder().url(WS_URL).build()

        val socket = client.newWebSocket(
            request,
            object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: Response) {
                    webSocket.send(packet(OP_AUTH, authPacket(cid).toByteArray()).toByteString())
                }

                override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                    parseFrames(bytes.toByteArray()).forEach { trySend(it) }
                }

                override fun onMessage(webSocket: WebSocket, text: String) {
                    // Kept for completeness; the server uses binary frames.
                    parseDanmakuJson(text).forEach { trySend(it) }
                }

                override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                    close(t)
                }

                override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                    close()
                }
            },
        )

        val heartbeat = launch {
            while (isActive) {
                delay(HEARTBEAT_MS)
                socket.send(
                    packet(OP_HEARTBEAT, HEARTBEAT_BODY.toByteArray()).toByteString(),
                )
            }
        }

        awaitClose {
            heartbeat.cancel()
            socket.close(1000, null)
        }
    }

    private companion object {
        val client: OkHttpClient by lazy { OkHttpClient() }
    }
}

private const val WS_URL = "wss://broadcastlv.chat.bilibili.com/sub"
private const val HEARTBEAT_MS = 30_000L
private const val HEARTBEAT_BODY = "[object Object]"

private const val OP_HEARTBEAT = 2
private const val OP_NOTIFICATION = 5
private const val OP_AUTH = 7

private const val HEADER_SIZE = 16

/** `protover = 2` = zlib-compressed JSON (no protobuf codegen needed). */
private fun authPacket(cid: Long): String =
    """{"uid":0,"roomid":$cid,"protover":2,"platform":"web","type":2,"key":""}"""

private fun packet(operation: Int, body: ByteArray): ByteArray {
    val total = HEADER_SIZE + body.size
    val out = ByteArray(total)
    writeInt(out, 0, total)
    writeShort(out, 4, HEADER_SIZE)
    // Client packets are plain JSON; the auth body negotiates response compression.
    writeShort(out, 6, 1)
    writeInt(out, 8, operation)
    writeInt(out, 12, 1)
    body.copyInto(out, HEADER_SIZE)
    return out
}

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

private fun writeInt(bytes: ByteArray, offset: Int, value: Int) {
    bytes[offset] = (value ushr 24).toByte()
    bytes[offset + 1] = (value ushr 16).toByte()
    bytes[offset + 2] = (value ushr 8).toByte()
    bytes[offset + 3] = value.toByte()
}

private fun writeShort(bytes: ByteArray, offset: Int, value: Int) {
    bytes[offset] = (value ushr 8).toByte()
    bytes[offset + 1] = value.toByte()
}

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
