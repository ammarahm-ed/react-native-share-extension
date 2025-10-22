package chat.rocket.rnshareextension

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.Intent.ACTION_SEND
import android.content.Intent.ACTION_SEND_MULTIPLE
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Parcelable
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import com.facebook.react.bridge.*
import java.io.File

class ShareModule(reactContext: ReactApplicationContext?) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName() = "ReactNativeShareExtension"

    @ReactMethod
    fun close() = reactApplicationContext.currentActivity?.finish()

    @ReactMethod
    fun data(promise: Promise) = promise.resolve(processIntent(reactApplicationContext.currentActivity))

    private fun processIntent(activity: Activity?): WritableArray {

        val items = Arguments.createArray()
        val currentActivity = activity ?: return items

        val intent = activity.intent

        val result = when {
            intent.action == ACTION_SEND && intent.isTypeOf("text/plain") -> actionSendText(
                intent,
                activity
            )
            intent.action == "android.intent.action.PROCESS_TEXT" -> actionSendText(
                intent,
                activity
            )
            intent.action == ACTION_SEND -> actionSendFile(intent, currentActivity)
            intent.action == ACTION_SEND_MULTIPLE -> actionSendMultiple(intent, currentActivity)
            else -> emptyList()
        }

        result.map {
            items.pushMap(it)
        }

        if (intent.extras != null) {
            val extras = Arguments.createMap();
            val keys = intent.extras!!.keySet();
            for (key in keys) {
                if (key.contains("SUBJECT") || key.contains("TITLE") || key.contains("TEXT")) {
                    extras.putString(key, intent.extras!!.getString(key));
                }
            }

            extras.putString("type", "extras");
            items.pushMap(extras);
        }

        return items
    }

    private fun actionSendMultiple(intent: Intent, activity: Activity): List<WritableMap> {
        val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) as? List<Uri>
            ?: emptyList()

        return uris.mapNotNull {
            createFilePathArgumentsMap(it, activity)
        }
    }

    private fun actionSendFile(intent: Intent, activity: Activity): List<WritableMap> {

        val uri = intent.getParcelableExtra<Parcelable>(Intent.EXTRA_STREAM) as? Uri
            ?: return emptyList()


        return createFilePathArgumentsMap(uri, activity)?.let { listOf(it) } ?: emptyList()
    }

    private fun actionSendText(intent: Intent, activity: Activity): List<WritableMap> {
        val uri = intent.getParcelableExtra<Parcelable>(Intent.EXTRA_STREAM) as? Uri
        if (uri != null) {
            return createFilePathArgumentsMap(uri, activity)?.let { listOf(it) } ?: emptyList()
        } else if (intent.action === "android.intent.action.PROCESS_TEXT") {
            return intent.getStringExtra(Intent.EXTRA_PROCESS_TEXT)
                ?.let { listOf(it.createMap("text")) }
                ?: return emptyList()
        } else {
            return intent.getStringExtra(Intent.EXTRA_TEXT)?.let { listOf(it.createMap("text")) }
                ?: return emptyList()
        }


    }

    private fun createFilePathArgumentsMap(uri: Uri, activity: Activity): WritableMap? {
        val map = Arguments.createMap();
        val type = activity.contentResolver.getType(uri);

        val (fileName, size) = activity.contentResolver.query(uri, null, null, null, null)
            .use { cursor ->
                if (cursor != null) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)

                    cursor.moveToFirst()
                    Pair(cursor.getString(nameIndex), cursor.getLong(sizeIndex));
                } else {
                    Pair("share-${System.currentTimeMillis()}.bin", 0L)
                }
            }

        val filePath = runCatching { createPrivateCopy(activity, type, uri) }
            .getOrDefault(null);
        map.putString("type", type);
        map.putString("value", filePath);
        map.putString("name", fileName);
        map.putDouble("size", size.toDouble())
        return map;
    }


    private fun createPrivateCopy(context: Context, type: String?, uri: Uri): String? {
        return context.contentResolver.openInputStream(uri).use {

            val file = File(
                context.cacheDir,
                "share-${System.currentTimeMillis()}.${
                    MimeTypeMap.getSingleton().getExtensionFromMimeType(type)
                }"
            );
            file.outputStream().use { out ->
                it?.copyTo(out, 16 * 1024);
                it?.close();
                out.close();
                file.absolutePath
            }
        }
    }
}

private fun String.createMap(type: String): WritableMap {

    return Arguments.createMap().apply {
        putString("value", this@createMap)
        putString("type", type)
    }
}

private fun Intent.isTypeOf(typePrefix: String): Boolean {
    return type?.startsWith(typePrefix) == true
}