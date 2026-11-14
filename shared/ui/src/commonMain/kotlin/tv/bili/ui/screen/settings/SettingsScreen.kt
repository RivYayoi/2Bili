package tv.bili.ui.screen.settings

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.koin.compose.viewmodel.koinViewModel
import tv.bili.core.platform.PlatformInfo
import tv.bili.ui.settings.AppSettings
import tv.bili.ui.settings.qualityOptions

@Composable
fun SettingsScreen(
    onBack: () -> Unit,
    viewModel: SettingsViewModel = koinViewModel(),
) {
    val settings by viewModel.state.collectAsStateWithLifecycle()

    SettingsContent(
        settings = settings,
        onBack = onBack,
        onDefaultQualityChange = viewModel::setDefaultQuality,
        onDanmakuEnabledChange = viewModel::setDanmakuEnabled,
        onDanmakuOpacityChange = viewModel::setDanmakuOpacity,
        onDanmakuFontScaleChange = viewModel::setDanmakuFontScale,
        onReset = viewModel::reset,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsContent(
    settings: AppSettings,
    onBack: () -> Unit,
    onDefaultQualityChange: (Int) -> Unit,
    onDanmakuEnabledChange: (Boolean) -> Unit,
    onDanmakuOpacityChange: (Float) -> Unit,
    onDanmakuFontScaleChange: (Float) -> Unit,
    onReset: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("设置") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
            )
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentAlignment = Alignment.TopCenter,
        ) {
            Column(
                modifier = Modifier
                    .widthIn(max = 760.dp)
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                SettingsSection("播放") {
                    Text("默认画质", style = MaterialTheme.typography.titleSmall)
                    Text(
                        text = "打开视频时优先使用该画质；当前视频不可用时自动回退。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        qualityOptions.forEach { option ->
                            FilterChip(
                                selected = settings.defaultQuality == option.qn,
                                onClick = { onDefaultQualityChange(option.qn) },
                                label = { Text(option.label) },
                            )
                        }
                    }
                }

                SettingsSection("弹幕") {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = "显示弹幕",
                            modifier = Modifier.weight(1f),
                            style = MaterialTheme.typography.titleSmall,
                        )
                        Switch(
                            checked = settings.danmakuEnabled,
                            onCheckedChange = onDanmakuEnabledChange,
                        )
                    }

                    Text(
                        text = "不透明度：${(settings.danmakuOpacity * 100).toInt()}%",
                        style = MaterialTheme.typography.bodySmall,
                    )
                    Slider(
                        value = settings.danmakuOpacity,
                        onValueChange = onDanmakuOpacityChange,
                        valueRange = 0.2f..1f,
                        steps = 7,
                    )

                    Text(
                        text = "字号：${(settings.danmakuFontScale * 100).toInt()}%",
                        style = MaterialTheme.typography.bodySmall,
                    )
                    Slider(
                        value = settings.danmakuFontScale,
                        onValueChange = onDanmakuFontScaleChange,
                        valueRange = 0.7f..1.5f,
                        steps = 7,
                    )
                }

                SettingsSection("关于") {
                    Text("2bili 1.0.4", style = MaterialTheme.typography.titleSmall)
                    Text(
                        text = "Kotlin Multiplatform + Compose Multiplatform",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = "平台：${PlatformInfo.platformName}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                OutlinedButton(
                    onClick = onReset,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("恢复默认设置")
                }
            }
        }
    }
}

@Composable
private fun SettingsSection(
    title: String,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = MaterialTheme.typography.titleMedium)
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                content = content,
            )
        }
    }
}
