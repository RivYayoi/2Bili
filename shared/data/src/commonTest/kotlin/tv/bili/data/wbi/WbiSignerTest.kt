package tv.bili.data.wbi

import kotlin.test.Test
import kotlin.test.assertEquals

class WbiSignerTest {

    /**
     * Golden vector from the public WBI documentation.
     *
     * img_key = 7cd084941338484aae1ad9425b84077c
     * sub_key = 4932caff0ff746eab6f01bf08b70ac45
     * -> mixin_key = ea1db124af3c7062474693fa704f4ff8
     */
    @Test
    fun `signing matches the reference vector`() {
        val signer = DefaultWbiSigner(FakeKeyProvider("ea1db124af3c7062474693fa704f4ff8"))

        val signed = signer.signAt(
            params = mapOf("foo" to "114", "bar" to "514", "zab" to "1919810"),
            wts = "1702204169",
            mixinKey = "ea1db124af3c7062474693fa704f4ff8",
        )

        assertEquals("8f6f2b5b3d485fe1886cec6a0be8c5d4", signed["w_rid"])
        assertEquals("1702204169", signed["wts"])
    }

    @Test
    fun `mixin key derivation is stable`() {
        val mixin = mixinKeyOf(
            "7cd084941338484aae1ad9425b84077c",
            "4932caff0ff746eab6f01bf08b70ac45",
        )
        assertEquals("ea1db124af3c7062474693fa704f4ff8", mixin)
    }
}

private class FakeKeyProvider(private val key: String) : WbiKeyProvider {
    override suspend fun mixinKey(forceRefresh: Boolean): String = key
}
