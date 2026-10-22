package com.gully.cricket.cricket_scoring

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import org.json.JSONObject

/**
 * Backup bridge.
 *
 * Two copies are written:
 *  1. app-specific external files: survives `adb install -r`, pullable by the
 *     update script, always readable by the app;
 *  2. public Downloads/CricScore: survives an uninstall and is what the fresh
 *     install auto-restore reads.
 *
 * Nothing here can touch the scoring engine. Failures are returned to Dart and
 * logged; the prefs on disk remain the source of truth.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.gully.cricket/backup"
        private const val BACKUP_FILE = "cricscore-backup.json"
        private const val PICK_REQUEST = 4917
        private const val MAX_BACKUP_BYTES = 8 * 1024 * 1024
        private const val DOWNLOADS_FOLDER = "CricScore"
    }

    private var pendingPick: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "writeBackup" -> {
                        val name = call.argument<String>("name") ?: BACKUP_FILE
                        val content = call.argument<String>("content")
                        if (content == null) {
                            result.error("bad_args", "content is missing", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(writeBackup(name, content))
                        } catch (e: Exception) {
                            result.error("write_failed", e.message, null)
                        }
                    }

                    "readBackup" -> {
                        try {
                            result.success(readBackup())
                        } catch (e: Exception) {
                            result.error("read_failed", e.message, null)
                        }
                    }

                    "pickBackup" -> {
                        if (pendingPick != null) {
                            result.error("busy", "the file picker is already open", null)
                            return@setMethodCallHandler
                        }
                        pendingPick = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            // A JSON copied in with adb or a file manager is
                            // often reported as application/octet-stream, so
                            // filtering to application/json can hide the very
                            // file the user needs. Dart validates the content.
                            type = "*/*"
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                putExtra(
                                    DocumentsContract.EXTRA_INITIAL_URI,
                                    Uri.parse(
                                        "content://com.android.providers.downloads.documents/root/downloads",
                                    ),
                                )
                            }
                        }
                        try {
                            startActivityForResult(intent, PICK_REQUEST)
                        } catch (e: Exception) {
                            pendingPick = null
                            result.error("pick_failed", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun backupDir(): File {
        // getExternalFilesDir is removed on uninstall but survives updates and
        // is reachable over adb without root. filesDir is the last fallback.
        val base = getExternalFilesDir(null) ?: filesDir
        return File(base, "backups")
    }

    private fun writeBackup(name: String, content: String): Map<String, Any?> {
        val appDir = backupDir()
        appDir.mkdirs()
        val appFile = File(appDir, name)
        // Write a sibling temp file and rename it into place. A crash or a
        // full disk must never leave a truncated JSON that is newer than the
        // public copy and therefore wins the next auto-restore.
        val tmp = File(appDir, "$name.tmp")
        tmp.writeText(content, Charsets.UTF_8)
        if (!tmp.renameTo(appFile)) {
            appFile.writeText(content, Charsets.UTF_8)
            tmp.delete()
        }

        var downloadsPath: String? = null
        try {
            downloadsPath = writeDownloads(name, content)
        } catch (e: Exception) {
            // Public copy is a bonus; the app copy above is the guaranteed one.
        }

        return mapOf(
            "ok" to true,
            "path" to appFile.absolutePath,
            "downloadsPath" to downloadsPath,
        )
    }

    private fun writeDownloads(name: String, content: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val relative = "${Environment.DIRECTORY_DOWNLOADS}/$DOWNLOADS_FOLDER/"
        // MediaStore renames an insert to "cricscore-backup (1).json" when a
        // file with the same display name already exists (for example one
        // copied in with adb). Matching the whole family keeps every later
        // save on one file instead of creating (2), (3), ... on every write.
        val prefix = name.removeSuffix(".json")
        val selection =
            "${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ? AND " +
                "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
        val args = arrayOf(
            "$prefix%",
            "${Environment.DIRECTORY_DOWNLOADS}/$DOWNLOADS_FOLDER%",
        )

        var displayName: String? = null
        var uri: Uri? = contentResolver.query(
            collection,
            arrayOf(
                MediaStore.MediaColumns._ID,
                MediaStore.MediaColumns.DISPLAY_NAME,
            ),
            selection,
            args,
            "${MediaStore.MediaColumns.DATE_MODIFIED} DESC",
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                displayName = cursor.getString(1)
                ContentUris.withAppendedId(collection, cursor.getLong(0))
            } else {
                null
            }
        }

        if (uri == null) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                put(MediaStore.MediaColumns.RELATIVE_PATH, relative)
            }
            uri = contentResolver.insert(collection, values)
            displayName = name
        }
        val target = uri ?: return null
        contentResolver.openOutputStream(target, "wt")?.use {
            it.write(content.toByteArray(Charsets.UTF_8))
        } ?: return null
        return "/sdcard/Download/$DOWNLOADS_FOLDER/${displayName ?: name}"
    }

    private data class Snapshot(val content: String, val modified: Long)

    /** A newer file that is not our JSON must not hide a good older copy. */
    private fun Snapshot.isUsable(): Boolean = try {
        val json = JSONObject(content)
        json.optString("app") == "cricscore" && json.optInt("format", 0) >= 1
    } catch (_: Exception) {
        false
    }

    /**
     * Return the newest usable of the app copy and the public Downloads copy.
     * The user may have copied a newer JSON into Downloads, and a fresh
     * install only has the Downloads copy, so "first file found" is not good
     * enough.
     */
    private fun readBackup(): String? {
        val newest = listOfNotNull(
            readAppBackup(),
            readDownloads(),
            readLegacyDownloads(),
        ).filter { it.isUsable() }
            .maxByOrNull { it.modified }
        return newest?.content
    }

    private fun readAppBackup(): Snapshot? {
        val file = File(backupDir(), BACKUP_FILE)
        if (!file.isFile || file.length() !in 1..MAX_BACKUP_BYTES.toLong()) {
            return null
        }
        return Snapshot(file.readText(Charsets.UTF_8), file.lastModified())
    }

    private fun readDownloads(): Snapshot? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val prefix = BACKUP_FILE.removeSuffix(".json")
        val selection =
            "${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ? AND " +
                "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
        val args = arrayOf(
            "$prefix%",
            "${Environment.DIRECTORY_DOWNLOADS}/$DOWNLOADS_FOLDER%",
        )
        var id = 0L
        var modified = 0L
        contentResolver.query(
            collection,
            arrayOf(
                MediaStore.MediaColumns._ID,
                MediaStore.MediaColumns.DATE_MODIFIED,
            ),
            selection,
            args,
            "${MediaStore.MediaColumns.DATE_MODIFIED} DESC",
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                id = cursor.getLong(0)
                // DATE_MODIFIED is seconds; the app file uses milliseconds.
                modified = cursor.getLong(1) * 1000L
            }
        }
        if (id == 0L) return null
        val uri = ContentUris.withAppendedId(collection, id)
        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: return null
        if (bytes.size !in 1..MAX_BACKUP_BYTES) return null
        return Snapshot(String(bytes, Charsets.UTF_8), modified)
    }

    @Suppress("DEPRECATION")
    private fun readLegacyDownloads(): Snapshot? {
        return try {
            val dir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS,
            )
            val files = File(dir, DOWNLOADS_FOLDER).listFiles { file ->
                file.isFile &&
                    file.name.startsWith("cricscore-backup") &&
                    file.name.endsWith(".json") &&
                    file.length() in 1..MAX_BACKUP_BYTES.toLong()
            } ?: return null
            val newest = files.maxByOrNull { it.lastModified() } ?: return null
            Snapshot(newest.readText(Charsets.UTF_8), newest.lastModified())
        } catch (e: Exception) {
            null
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == PICK_REQUEST) {
            val pending = pendingPick
            pendingPick = null
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                pending?.success(null)
                return
            }
            try {
                pending?.success(readUri(data.data!!))
            } catch (e: Exception) {
                pending?.error("read_failed", e.message, null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun readUri(uri: Uri): String? {
        return contentResolver.openInputStream(uri)?.use { input ->
            val bytes = input.readBytes()
            if (bytes.size in 1..MAX_BACKUP_BYTES) {
                String(bytes, Charsets.UTF_8)
            } else {
                null
            }
        }
    }
}
