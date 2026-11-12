package tv.bili.ui.navigation

import kotlinx.serialization.Serializable

@Serializable
data object HomeRoute

@Serializable
data class DetailRoute(val bvid: String)

@Serializable
data class PlayerRoute(
    val bvid: String,
    val cid: Long,
    val title: String,
)

@Serializable
data object SearchRoute

@Serializable
data object LoginRoute
