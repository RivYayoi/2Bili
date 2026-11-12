package tv.bili.domain.player

import kotlinx.coroutines.flow.StateFlow

/**
 * The only player contract the shared layer knows about.
 *
 * It is a plain interface (not expect/actual) so that:
 *  - ViewModels can be unit-tested with a FakePlayerController;
 *  - platform modules never leak VLCJ / Media3 types into commonMain.
 *
 * Only the *factory* and the *surface composable* are expect/actual.
 */
interface PlayerController {
    val state: StateFlow<PlayerState>

    fun setSource(source: PlaySource)
    fun play()
    fun pause()
    fun seekTo(positionMs: Long)
    fun setSpeed(speed: Float)
    fun release()
}

data class PlayerState(
    val phase: Phase = Phase.Idle,
    val isPlaying: Boolean = false,
    val positionMs: Long = 0L,
    val durationMs: Long = 0L,
    val bufferedMs: Long = 0L,
    val speed: Float = 1f,
    val videoWidth: Int = 0,
    val videoHeight: Int = 0,
    val error: String? = null,
) {
    enum class Phase { Idle, Preparing, Ready, Ended, Error }
}
