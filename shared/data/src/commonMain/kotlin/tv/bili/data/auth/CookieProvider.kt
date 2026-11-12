package tv.bili.data.auth

interface CookieProvider {
    /** Returns a ready-to-send Cookie header, or null when nothing is stored yet. */
    suspend fun cookieHeader(): String?
}
