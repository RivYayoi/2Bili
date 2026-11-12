package tv.bili.data.api

import kotlinx.serialization.json.Json

val BiliJson: Json = Json {
    ignoreUnknownKeys = true
    isLenient = true
    coerceInputValues = true
    explicitNulls = false
}
