package com.tempic.sheet_music_viewer

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Bridges two things Flutter plugins don't cover well for this app:
 *  - PDFs shared to / opened with the app (copied into the cache dir so Dart can import them)
 *  - Saving a large file (library backup) to a user-chosen location without loading it into memory
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var initialIntentHandled = false
    private var pendingSave: Pair<String, MethodChannel.Result>? = null
    private val io = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedFiles" -> {
                        if (initialIntentHandled) {
                            result.success(null)
                        } else {
                            initialIntentHandled = true
                            copySharedFiles(intent) { shared -> result.success(shared) }
                        }
                    }
                    "saveFileAs" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val fileName = call.argument<String>("fileName")
                        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                        if (sourcePath == null || fileName == null || pendingSave != null) {
                            result.success(false)
                        } else {
                            pendingSave = sourcePath to result
                            val create = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = mimeType
                                putExtra(Intent.EXTRA_TITLE, fileName)
                            }
                            @Suppress("DEPRECATION")
                            startActivityForResult(create, REQUEST_SAVE_FILE)
                        }
                    }
                    "getAppVersion" -> {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode
                        else @Suppress("DEPRECATION") info.versionCode.toLong()
                        result.success(mapOf("name" to info.versionName, "code" to code))
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        copySharedFiles(intent) { shared ->
            if (shared != null) channel?.invokeMethod("filesShared", shared)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_SAVE_FILE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val (sourcePath, result) = pendingSave ?: return
        pendingSave = null
        val target = data?.data
        if (resultCode != Activity.RESULT_OK || target == null) {
            result.success(false)
            return
        }
        io.execute {
            val ok = try {
                File(sourcePath).inputStream().use { input ->
                    contentResolver.openOutputStream(target, "w")!!.use { output -> input.copyTo(output) }
                }
                true
            } catch (e: Exception) {
                Log.w(TAG, "Saving to $target failed", e)
                false
            }
            mainHandler.post { result.success(ok) }
        }
    }

    /**
     * Copies the intent's PDFs into the cache dir. Reports
     * `{paths: [local copies], failed: [names that couldn't be read]}`, or null if
     * the intent carried no files.
     */
    private fun copySharedFiles(intent: Intent?, onDone: (Map<String, List<String>>?) -> Unit) {
        val uris = sharedUris(intent)
        if (uris.isEmpty()) {
            onDone(null)
            return
        }
        io.execute {
            val failed = mutableListOf<String>()
            val paths = uris.mapIndexedNotNull { index, uri ->
                try {
                    // Keep the original file name (used for duplicate detection on import);
                    // a per-file subfolder avoids collisions between same-named files.
                    val dir = File(cacheDir, "shared/${System.currentTimeMillis()}_$index").apply { mkdirs() }
                    val dest = File(dir, displayName(uri))
                    contentResolver.openInputStream(uri)!!.use { input ->
                        dest.outputStream().use { output -> input.copyTo(output) }
                    }
                    dest.absolutePath
                } catch (e: Exception) {
                    Log.w(TAG, "Couldn't read shared file $uri", e)
                    // Without read access we can't query the real name; avoid showing a bare ID.
                    failed.add(uri.lastPathSegment?.takeIf { it.contains('.') } ?: "Shared file")
                    null
                }
            }
            mainHandler.post { onDone(mapOf("paths" to paths, "failed" to failed)) }
        }
    }

    private fun sharedUris(intent: Intent?): List<Uri> {
        if (intent == null) return emptyList()
        return when (intent.action) {
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            Intent.ACTION_SEND -> listOfNotNull(
                if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                else @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
            )
            Intent.ACTION_SEND_MULTIPLE ->
                (if (Build.VERSION.SDK_INT >= 33) intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                else @Suppress("DEPRECATION") intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM))
                    ?: emptyList()
            else -> emptyList()
        }
    }

    private fun displayName(uri: Uri): String {
        var name: String? = null
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) name = cursor.getString(0)
            }
        } catch (e: Exception) {
            // Fall back to the URI's path below.
        }
        // Strip any path components so the name can't escape the target directory.
        val cleaned = File(name ?: uri.lastPathSegment ?: "shared.pdf").name
        return if (cleaned.isBlank()) "shared.pdf" else cleaned
    }

    companion object {
        private const val TAG = "SheetMusicViewer"
        private const val CHANNEL = "sheet_music_viewer/files"
        private const val REQUEST_SAVE_FILE = 4201
    }
}
