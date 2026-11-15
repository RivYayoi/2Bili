package tv.bili.ui.screen.detail

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import tv.bili.core.error.AppError
import tv.bili.core.result.AppResult
import tv.bili.domain.model.CommentSort
import tv.bili.domain.model.VideoComment
import tv.bili.domain.model.VideoDetail
import tv.bili.domain.repository.VideoRepository

data class CommentsUiState(
    val items: List<VideoComment> = emptyList(),
    val totalCount: Long = 0L,
    val sort: CommentSort = CommentSort.Hot,
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasMore: Boolean = false,
    val nextOffset: String? = null,
    val error: AppError? = null,
    val expandedReplies: Map<Long, List<VideoComment>> = emptyMap(),
    val loadingReplies: Set<Long> = emptySet(),
    val replyErrors: Map<Long, AppError> = emptyMap(),
    val replyHasMore: Map<Long, Boolean> = emptyMap(),
    val replyNextPage: Map<Long, Int> = emptyMap(),
)

data class VideoDetailUiState(
    val detail: VideoDetail? = null,
    val isLoading: Boolean = true,
    val error: AppError? = null,
    val comments: CommentsUiState = CommentsUiState(),
)

class VideoDetailViewModel(
    private val repository: VideoRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(VideoDetailUiState())
    val state: StateFlow<VideoDetailUiState> = _state.asStateFlow()

    private var currentBvid: String? = null
    private var job: Job? = null
    private var commentsJob: Job? = null
    private val replyJobs = mutableMapOf<Long, Job>()

    fun load(bvid: String, force: Boolean = false) {
        if (!force && currentBvid == bvid && _state.value.detail != null) return
        val sameVideo = currentBvid == bvid
        currentBvid = bvid

        job?.cancel()
        commentsJob?.cancel()
        replyJobs.values.forEach { it.cancel() }
        replyJobs.clear()

        if (!sameVideo) {
            _state.value = VideoDetailUiState()
        }

        job = viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }

            when (val result = repository.detail(bvid)) {
                is AppResult.Success -> {
                    _state.update {
                        it.copy(detail = result.value, isLoading = false, error = null)
                    }
                    loadComments(result.value.aid, reset = true)
                }

                is AppResult.Failure -> _state.update {
                    it.copy(isLoading = false, error = result.error)
                }
            }
        }
    }

    fun retry() {
        currentBvid?.let { load(it, force = true) }
    }

    fun setCommentSort(sort: CommentSort) {
        if (_state.value.comments.sort == sort) return
        _state.update { it.copy(comments = it.comments.copy(sort = sort)) }
        val aid = _state.value.detail?.aid ?: return
        loadComments(aid, reset = true)
    }

    fun retryComments() {
        val aid = _state.value.detail?.aid ?: return
        loadComments(aid, reset = true)
    }

    fun loadMoreComments() {
        val aid = _state.value.detail?.aid ?: return
        val comments = _state.value.comments
        if (comments.isLoading || comments.isLoadingMore || !comments.hasMore || comments.nextOffset == null) {
            return
        }
        loadComments(aid, reset = false)
    }

    private fun loadComments(aid: Long, reset: Boolean) {
        val snapshot = _state.value.comments
        if (!reset && (
                snapshot.isLoading ||
                    snapshot.isLoadingMore ||
                    !snapshot.hasMore ||
                    snapshot.nextOffset == null
                )
        ) {
            return
        }

        if (reset) {
            replyJobs.values.forEach { it.cancel() }
            replyJobs.clear()
        }

        val sort = snapshot.sort
        val offset = if (reset) null else snapshot.nextOffset
        commentsJob?.cancel()
        commentsJob = viewModelScope.launch {
            _state.update { current ->
                current.copy(
                    comments = current.comments.copy(
                        items = if (reset) emptyList() else current.comments.items,
                        isLoading = reset,
                        isLoadingMore = !reset,
                        hasMore = if (reset) false else current.comments.hasMore,
                        nextOffset = if (reset) null else current.comments.nextOffset,
                        error = null,
                        expandedReplies = if (reset) emptyMap() else current.comments.expandedReplies,
                        loadingReplies = if (reset) emptySet() else current.comments.loadingReplies,
                        replyErrors = if (reset) emptyMap() else current.comments.replyErrors,
                        replyHasMore = if (reset) emptyMap() else current.comments.replyHasMore,
                        replyNextPage = if (reset) emptyMap() else current.comments.replyNextPage,
                    ),
                )
            }

            when (val result = repository.comments(aid, sort, offset)) {
                is AppResult.Success -> _state.update { current ->
                    val existing = if (reset) emptyList() else current.comments.items
                    val merged = (existing + result.value.items).distinctBy { it.rpid }
                    current.copy(
                        comments = current.comments.copy(
                            items = merged,
                            totalCount = result.value.totalCount,
                            isLoading = false,
                            isLoadingMore = false,
                            // If a page only contains duplicates we stop instead
                            // of letting the scroll listener request it forever.
                            hasMore = result.value.hasMore && merged.size > existing.size,
                            nextOffset = result.value.nextOffset,
                            error = null,
                        ),
                    )
                }

                is AppResult.Failure -> _state.update { current ->
                    current.copy(
                        comments = current.comments.copy(
                            isLoading = false,
                            isLoadingMore = false,
                            error = result.error,
                        ),
                    )
                }
            }
        }
    }

    fun loadReplies(root: Long) {
        val aid = _state.value.detail?.aid ?: return
        val comments = _state.value.comments
        if (root in comments.loadingReplies) return
        val expanded = comments.expandedReplies.containsKey(root)
        if (expanded && comments.replyHasMore[root] == false) return

        val page = comments.replyNextPage[root] ?: 1
        replyJobs[root]?.cancel()
        replyJobs[root] = viewModelScope.launch {
            _state.update { current ->
                current.copy(
                    comments = current.comments.copy(
                        loadingReplies = current.comments.loadingReplies + root,
                        replyErrors = current.comments.replyErrors - root,
                    ),
                )
            }

            when (val result = repository.replies(aid, root, page)) {
                is AppResult.Success -> _state.update { current ->
                    val preview = current.comments.items
                        .firstOrNull { it.rpid == root }
                        ?.replies
                        .orEmpty()
                    val existing = current.comments.expandedReplies[root].orEmpty()
                    val base = if (existing.isEmpty()) preview else existing
                    val merged = (base + result.value.items).distinctBy { it.rpid }
                    current.copy(
                        comments = current.comments.copy(
                            expandedReplies = current.comments.expandedReplies + (root to merged),
                            loadingReplies = current.comments.loadingReplies - root,
                            replyHasMore = current.comments.replyHasMore + (root to result.value.hasMore),
                            replyNextPage = current.comments.replyNextPage +
                                (root to (result.value.nextPage ?: (page + 1))),
                            replyErrors = current.comments.replyErrors - root,
                        ),
                    )
                }

                is AppResult.Failure -> _state.update { current ->
                    current.copy(
                        comments = current.comments.copy(
                            loadingReplies = current.comments.loadingReplies - root,
                            replyErrors = current.comments.replyErrors + (root to result.error),
                        ),
                    )
                }
            }
        }
    }
}
