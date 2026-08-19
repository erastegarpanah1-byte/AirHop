package com.airhop.airhop

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val CHANNEL = "airhop/file_storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveFile" -> saveFile(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveFile(call: MethodCall, result: MethodChannel.Result) {
        try {
            val fileName = call.argument<String>("fileName") ?: "file"
            val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
            val category = call.argument<String>("category") ?: "فایل‌ها"
            val bytes = call.argument<ByteArray>("bytes") ?: throw IllegalArgumentException("no bytes")

            val path = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveViaMediaStore(fileName, mimeType, category, bytes)
            } else {
                saveLegacy(fileName, mimeType, category, bytes)
            }

            // حتماً گالری را وادار به اسکن فایل تازه کن (برای اندروید 7 و همه نسخه‌ها)
            scanFile(path, mimeType)

            result.success(path)
        } catch (e: Exception) {
            result.error("SAVE_FAILED", e.message ?: "unknown", null)
        }
    }

    // Android 10+ → MediaStore (بدون نیاز به permission، در گالری نمایش داده می‌شود)
    private fun saveViaMediaStore(
        name: String,
        mime: String,
        category: String,
        bytes: ByteArray
    ): String {
        val resolver = contentResolver
        val collection = when {
            mime.startsWith("image/") -> MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            mime.startsWith("video/") -> MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            mime.startsWith("audio/") -> MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            else -> MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, "AirHop/$category")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("insert returned null")

        resolver.openOutputStream(uri)?.use { os ->
            os.write(bytes)
            os.flush()
        } ?: run {
            resolver.delete(uri, null, null)
            throw IllegalStateException("openOutputStream returned null")
        }

        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(uri, values, null, null)

        return "AirHop/$category/$name"
    }

    // Android 7-9 → فایل مستقیم + index گالری
    private fun saveLegacy(
        name: String,
        mime: String,
        category: String,
        bytes: ByteArray
    ): String {
        val root = Environment.getExternalStorageDirectory().absolutePath
        val dir = File(root, "AirHop/$category")
        if (!dir.exists()) dir.mkdirs()

        var target = File(dir, name)
        if (target.exists()) {
            val dot = name.lastIndexOf('.')
            val ext = if (dot >= 0) name.substring(dot) else ""
            val base = if (dot >= 0) name.substring(0, dot) else name
            var i = 1
            while (target.exists()) {
                target = File(dir, "${base}_($i)$ext")
                i++
            }
        }

        FileOutputStream(target).use { it.write(bytes) }
        return target.absolutePath
    }

    // وادار کردن گالری به اسکن فایل (مخصوص اندروید 7 که MediaStore خودکار آپدیت نمی‌شود)
    private fun scanFile(path: String, mime: String) {
        try {
            MediaScannerConnection.scanFile(
                this,
                arrayOf(path),
                arrayOf(mime),
                null
            )
        } catch (_: Exception) {
            // ignore — scan is best-effort
        }
    }
}
