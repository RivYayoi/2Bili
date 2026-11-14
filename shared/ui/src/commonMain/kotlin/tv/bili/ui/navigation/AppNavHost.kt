package tv.bili.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import tv.bili.ui.screen.detail.VideoDetailScreen
import tv.bili.ui.screen.home.HomeScreen
import tv.bili.ui.screen.login.QrLoginScreen
import tv.bili.ui.screen.player.PlayerScreen
import tv.bili.ui.screen.search.SearchScreen
import tv.bili.ui.screen.settings.SettingsScreen

@Composable
fun AppNavHost(
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    NavHost(
        navController = navController,
        startDestination = HomeRoute,
        modifier = modifier,
    ) {
        composable<HomeRoute> {
            HomeScreen(
                onVideoClick = { bvid -> navController.navigate(DetailRoute(bvid)) },
                onSearchClick = { navController.navigate(SearchRoute) },
                onLoginClick = { navController.navigate(LoginRoute) },
                onSettingsClick = { navController.navigate(SettingsRoute) },
            )
        }

        composable<DetailRoute> { entry ->
            val route = entry.toRoute<DetailRoute>()
            VideoDetailScreen(
                bvid = route.bvid,
                onBack = { navController.popBackStack() },
                onPlay = { cid, title ->
                    navController.navigate(PlayerRoute(route.bvid, cid, title))
                },
            )
        }

        composable<PlayerRoute> { entry ->
            val route = entry.toRoute<PlayerRoute>()
            PlayerScreen(
                bvid = route.bvid,
                cid = route.cid,
                title = route.title,
                onBack = { navController.popBackStack() },
            )
        }

        composable<SearchRoute> {
            SearchScreen(
                onBack = { navController.popBackStack() },
                onVideoClick = { bvid -> navController.navigate(DetailRoute(bvid)) },
            )
        }

        composable<LoginRoute> {
            QrLoginScreen(
                onBack = { navController.popBackStack() },
                onLoggedIn = { navController.popBackStack() },
            )
        }

        composable<SettingsRoute> {
            SettingsScreen(
                onBack = { navController.popBackStack() },
            )
        }
    }
}
