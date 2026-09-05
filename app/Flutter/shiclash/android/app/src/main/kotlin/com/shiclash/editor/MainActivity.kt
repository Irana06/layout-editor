package com.shiclash.editor

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "shiclash/app_installer",
        ).setMethodCallHandler { call, result ->
            if (call.method != "installApk") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("INVALID_PATH", "Path APK tidak tersedia.", null)
                return@setMethodCallHandler
            }
            installApk(path, result)
        }
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        try {
            val apk = File(path).canonicalFile
            val cache = cacheDir.canonicalFile
            if (!apk.path.startsWith(cache.path + File.separator) ||
                !apk.name.endsWith(".apk", ignoreCase = true) ||
                !apk.isFile
            ) {
                result.error("INVALID_APK", "File APK tidak valid.", null)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                !packageManager.canRequestPackageInstalls()
            ) {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:$packageName"),
                    ),
                )
                result.success(mapOf("status" to "permission_required"))
                return
            }

            val apkUri = FileProvider.getUriForFile(
                this,
                "$packageName.updates",
                apk,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                clipData = ClipData.newRawUri("Shiclash update", apkUri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(mapOf("status" to "opened"))
        } catch (error: Exception) {
            result.error(
                "INSTALLER_FAILED",
                error.localizedMessage ?: "Installer Android tidak dapat dibuka.",
                null,
            )
        }
    }
}
