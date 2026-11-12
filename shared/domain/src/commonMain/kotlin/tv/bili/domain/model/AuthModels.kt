package tv.bili.domain.model

data class QrTicket(
    val url: String,
    val key: String,
)

data class QrPoll(
    val status: QrStatus,
    val message: String,
    val credential: Credential? = null,
)

enum class QrStatus {
    Waiting,
    Scanned,
    Expired,
    Success,
}
