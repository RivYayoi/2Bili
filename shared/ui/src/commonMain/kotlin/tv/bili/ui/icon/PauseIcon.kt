package tv.bili.ui.icon

import androidx.compose.material.icons.materialIcon
import androidx.compose.material.icons.materialPath
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * The only Material icon we used from `material-icons-extended`.
 *
 * Keeping a local vector avoids pulling the ~37 MB extended icon jar into
 * both the desktop app image and the Android APK.
 */
val PauseIcon: ImageVector = materialIcon(name = "Filled.Pause") {
    materialPath {
        moveTo(6.0f, 19.0f)
        horizontalLineToRelative(4.0f)
        verticalLineTo(5.0f)
        horizontalLineTo(6.0f)
        verticalLineToRelative(14.0f)
        close()
        moveTo(14.0f, 5.0f)
        verticalLineToRelative(14.0f)
        horizontalLineToRelative(4.0f)
        verticalLineTo(5.0f)
        horizontalLineToRelative(-4.0f)
        close()
    }
}
