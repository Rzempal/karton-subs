package app.michalrapala.zostaje

import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import app.michalrapala.ai_engine.IAiCallback
import app.michalrapala.ai_engine.IAiEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Mostek do Lokalnego Silnika AI (Mechanizm 2): bind do uslugi AIDL silnika,
 * zdjecie przez ParcelFileDescriptor, JSON wraca callbackiem.
 *
 * ZAWSZE pakiet PRODUKCYJNY silnika (app.michalrapala.ai_engine) - takze
 * w buildzie dev Zostaje. Silnik DEV (.dev) to osobna apka wylacznie do
 * testow samego silnika (Developer tools).
 *
 * Prywatnosc: zdjecie idzie do apki-silnika NA TYM SAMYM urzadzeniu
 * (wnioskowanie on-device) - nic nie opuszcza telefonu.
 */
class AiEngineBridge(private val context: Context) {

    private val main = Handler(Looper.getMainLooper())

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "engineStatus" -> engineStatus(result)
            "scanBill" -> {
                val path = call.argument<String>("imagePath")
                if (path.isNullOrBlank()) {
                    result.error("BAD_INPUT", "Brak sciezki zdjecia", null)
                } else {
                    scanBill(path, result)
                }
            }
            "openEngineApp" -> openEngineApp(result)
            "openUrl" -> openUrl(call.argument<String>("url"), result)
            "archiveReceipt" -> archiveReceipt(
                call.argument<String>("imagePath"),
                call.argument<String>("subfolder"),
                call.argument<String>("filename"),
                result,
            )
            else -> result.notImplemented()
        }
    }

    /**
     * Trwale kopiuje zdjecie rachunku do publicznego katalogu Documents/<subfolder>.
     * Android 10+ (Q): przez MediaStore, bez zadnych uprawnien. Starsze: zapis
     * bezposredni (WRITE_EXTERNAL_STORAGE z manifestu). Zwraca sciezke docelowa.
     */
    private fun archiveReceipt(
        imagePath: String?,
        subfolder: String?,
        filename: String?,
        result: MethodChannel.Result,
    ) {
        if (imagePath.isNullOrBlank() || filename.isNullOrBlank()) {
            result.error("BAD_INPUT", "Brak sciezki zdjecia lub nazwy pliku", null)
            return
        }
        val src = File(imagePath)
        if (!src.exists()) {
            result.error("BAD_INPUT", "Plik zdjecia nie istnieje", null)
            return
        }
        val folder = (subfolder ?: "Zostaje").trim().trim('/').ifBlank { "Zostaje" }
        try {
            val saved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                archiveViaMediaStore(src, folder, filename)
            } else {
                archiveLegacy(src, folder, filename)
            }
            result.success(saved)
        } catch (t: Throwable) {
            result.error("ARCHIVE_ERROR", t.message ?: "Blad zapisu do archiwum", null)
        }
    }

    private fun archiveViaMediaStore(src: File, folder: String, filename: String): String {
        val resolver = context.contentResolver
        val relPath = "${Environment.DIRECTORY_DOCUMENTS}/$folder"
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeFor(filename))
            put(MediaStore.MediaColumns.RELATIVE_PATH, relPath)
        }
        val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = resolver.insert(collection, values)
            ?: error("Nie mozna utworzyc pliku w $relPath")
        resolver.openOutputStream(uri).use { out ->
            requireNotNull(out) { "Brak strumienia zapisu" }
            FileInputStream(src).use { it.copyTo(out) }
        }
        return "/$relPath/$filename"
    }

    private fun archiveLegacy(src: File, folder: String, filename: String): String {
        @Suppress("DEPRECATION")
        val base = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
        val dir = File(base, folder).apply { mkdirs() }
        val dest = File(dir, filename)
        FileInputStream(src).use { input -> dest.outputStream().use { input.copyTo(it) } }
        return dest.absolutePath
    }

    private fun mimeFor(name: String): String = when (name.substringAfterLast('.').lowercase()) {
        "png" -> "image/png"
        "webp" -> "image/webp"
        else -> "image/jpeg"
    }

    /** Uruchamia apke silnika (ekran zarzadzania modelem). */
    private fun openEngineApp(result: MethodChannel.Result) {
        val intent = context.packageManager.getLaunchIntentForPackage(ENGINE_PACKAGE)
        if (intent == null) {
            result.error(
                "ENGINE_NOT_INSTALLED",
                "Apka Lokalny Silnik AI nie jest zainstalowana",
                null,
            )
            return
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        result.success(true)
    }

    /** Otwiera adres w przegladarce (np. pobranie APK silnika). */
    private fun openUrl(url: String?, result: MethodChannel.Result) {
        if (url.isNullOrBlank()) {
            result.error("BAD_INPUT", "Brak adresu URL", null)
            return
        }
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { context.startActivity(intent) }
            .onSuccess { result.success(true) }
            .onFailure { result.error("NO_BROWSER", "Nie mozna otworzyc adresu", null) }
    }

    /** Status silnika: zainstalowany? model pobrany? model w pamieci? */
    private fun engineStatus(result: MethodChannel.Result) {
        if (!isEngineInstalled()) {
            result.success(
                mapOf("installed" to false, "modelReady" to false, "modelLoaded" to false),
            )
            return
        }
        withEngine(
            result,
            timeoutMs = STATUS_TIMEOUT_MS,
            onConnected = { engine, finish ->
                val ready = engine.isModelReady
                val loaded = engine.isModelLoaded
                finish {
                    result.success(
                        mapOf("installed" to true, "modelReady" to ready, "modelLoaded" to loaded),
                    )
                }
            },
        )
    }

    /** OCR rachunku: zwraca surowy JSON {"rachunki":[...]} z silnika. */
    private fun scanBill(path: String, result: MethodChannel.Result) {
        val file = File(path)
        if (!file.exists()) {
            result.error("BAD_INPUT", "Plik zdjecia nie istnieje: $path", null)
            return
        }
        val mime = when (file.extension.lowercase()) {
            "png" -> "image/png"
            "webp" -> "image/webp"
            "gif" -> "image/gif"
            else -> "image/jpeg"
        }
        withEngine(
            result,
            timeoutMs = SCAN_TIMEOUT_MS,
            onConnected = { engine, finish ->
                val cb = object : IAiCallback.Stub() {
                    override fun onResult(json: String?) {
                        finish { result.success(json ?: "") }
                    }
                    override fun onError(code: String?, message: String?) {
                        finish { result.error(code ?: "ENGINE_ERROR", message, null) }
                    }
                }
                // Binder duplikuje deskryptor przy przekazaniu miedzy procesami;
                // wlasny uchwyt zamykamy od razu, silnik zamyka swoj.
                val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                try {
                    engine.recognizeBill(pfd, mime, cb)
                } finally {
                    runCatching { pfd.close() }
                }
            },
        )
    }

    /**
     * Wspolny cykl: bind -> praca -> unbind (przez [finish], dokladnie raz).
     * [onConnected] dostaje polaczony interfejs i funkcje domykajaca; bledy,
     * timeout i rozlaczenie uslugi tez koncza wywolanie przez [finish].
     */
    private fun withEngine(
        result: MethodChannel.Result,
        timeoutMs: Long,
        onConnected: (IAiEngine, finish: (block: () -> Unit) -> Unit) -> Unit,
    ) {
        val done = AtomicBoolean(false)
        var connRef: ServiceConnection? = null

        fun finish(block: () -> Unit) {
            if (done.compareAndSet(false, true)) {
                main.post {
                    connRef?.let { runCatching { context.unbindService(it) } }
                    block()
                }
            }
        }

        val conn = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                try {
                    onConnected(IAiEngine.Stub.asInterface(binder), ::finish)
                } catch (t: Throwable) {
                    finish { result.error("ENGINE_ERROR", t.message ?: "Blad silnika", null) }
                }
            }

            override fun onServiceDisconnected(name: ComponentName?) {
                finish { result.error("ENGINE_DISCONNECTED", "Usluga silnika rozlaczona", null) }
            }
        }
        connRef = conn

        val intent = Intent(BIND_ACTION).setPackage(ENGINE_PACKAGE)
        val bound = runCatching { context.bindService(intent, conn, Context.BIND_AUTO_CREATE) }
            .getOrDefault(false)
        if (!bound) {
            finish {
                result.error(
                    "ENGINE_NOT_INSTALLED",
                    "Nie mozna wpiac sie do Lokalnego Silnika AI - zainstaluj apke silnika",
                    null,
                )
            }
            return
        }
        main.postDelayed(
            { finish { result.error("TIMEOUT", "Silnik nie odpowiedzial w czasie ${timeoutMs / 1000} s", null) } },
            timeoutMs,
        )
    }

    private fun isEngineInstalled(): Boolean =
        runCatching { context.packageManager.getPackageInfo(ENGINE_PACKAGE, 0) }.isSuccess

    companion object {
        const val CHANNEL = "zostaje/ai_engine"

        /** Pakiet PRODUKCYJNY silnika - jedyny, do ktorego binduja klienci. */
        private const val ENGINE_PACKAGE = "app.michalrapala.ai_engine"
        private const val BIND_ACTION = "app.michalrapala.ai_engine.BIND"

        private const val STATUS_TIMEOUT_MS = 10_000L

        /** OCR na CPU trwa ~30-46 s + ewentualne ladowanie modelu (~10 s) + kolejka. */
        private const val SCAN_TIMEOUT_MS = 180_000L
    }
}
