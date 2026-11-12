package tv.bili.domain.model

data class Paged<T>(
    val items: List<T>,
    val page: Int,
    val hasMore: Boolean,
)
