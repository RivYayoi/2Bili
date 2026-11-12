package tv.bili.data.repository

import tv.bili.core.result.AppResult
import tv.bili.core.result.map
import tv.bili.core.result.onSuccess
import tv.bili.data.api.BiliApiClient
import tv.bili.data.auth.CredentialRepository
import tv.bili.data.auth.QrLoginApi
import tv.bili.data.dto.NavDto
import tv.bili.data.mapper.normalizeBiliUrl
import tv.bili.domain.model.Credential
import tv.bili.domain.model.QrPoll
import tv.bili.domain.model.QrTicket
import tv.bili.domain.model.User
import tv.bili.domain.repository.AuthRepository

class AuthRepositoryImpl(
    private val api: BiliApiClient,
    private val qrLoginApi: QrLoginApi,
    private val credentials: CredentialRepository,
) : AuthRepository {

    override suspend fun generateQr(): AppResult<QrTicket> = qrLoginApi.generate()

    override suspend fun pollQr(key: String): AppResult<QrPoll> =
        qrLoginApi.poll(key).onSuccess { poll ->
            poll.credential?.let { credentials.save(it) }
        }

    override suspend fun currentUser(): AppResult<User?> =
        api.get<NavDto>("/x/web-interface/nav").map { nav ->
            if (nav.isLogin) {
                User(
                    mid = nav.mid,
                    name = nav.uname,
                    faceUrl = nav.face.normalizeBiliUrl(),
                )
            } else {
                null
            }
        }

    override suspend fun saveCredential(credential: Credential) = credentials.save(credential)

    override suspend fun logout() = credentials.clear()
}
