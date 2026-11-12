package tv.bili.domain.model

data class Credential(
    val sessData: String,
    val biliJct: String,
    val dedeUserId: String,
    val refreshToken: String = "",
)
