package tv.bili.domain.repository

import kotlinx.coroutines.flow.Flow
import tv.bili.core.result.AppResult
import tv.bili.domain.model.Credential
import tv.bili.domain.model.QrPoll
import tv.bili.domain.model.QrTicket
import tv.bili.domain.model.User

interface AuthRepository {
    suspend fun generateQr(): AppResult<QrTicket>
    suspend fun pollQr(key: String): AppResult<QrPoll>
    suspend fun currentUser(): AppResult<User?>
    suspend fun saveCredential(credential: Credential)
    suspend fun logout()
}
