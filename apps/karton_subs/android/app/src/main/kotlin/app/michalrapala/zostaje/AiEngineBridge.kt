package app.michalrapala.zostaje

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import app.michalrapala.ai_engine.IAiCallback
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

/**
 * Mostek do Lokalnego Silnika AI (Mechanizm 2): zlecenia z warstwy Dart.
 *
 * Rozpoznawanie rachunku nie dzieje sie tutaj, tylko w [BillScanService]
 * (usluga pierwszoplanowa, ADR-016) - inaczej wyjscie z apki w trakcie OCR
 * konczylo sie ubiciem procesu i utrata skanu. Mostek zleca prace i oddaje
 * wyniki ze skrzynki [ScanResultStore].
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
    private var channel: MethodChannel? = null

    /**
     * Podpina kanal do warstwy Dart: dopoki zyje, wyniki skanow sa do niej
     * zglaszane od razu (i to ona pokazuje powiadomienie z nazwa rachunku).
     */
    fun attach(channel: MethodChannel) {
        this.channel = channel
        ScanResultStore.setListener {
            main.post { this.channel?.invokeMethod("scanResultsAvailable", null) }
        }
    }

    /** Warstwa Flutter znika (np. zamkniecie ekranu) - usluga pracuje dalej. */
    fun detach() {
        ScanResultStore.setListener(null)
        channel = null
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "engineStatus" -> engineStatus(result)
            "startBillScan" -> {
                val scanId = call.argument<String>("scanId")
                val path = call.argument<String>("imagePath")
                if (scanId.isNullOrBlank() || path.isNullOrBlank()) {
                    result.error("BAD_INPUT", "Brak identyfikatora skanu lub sciezki zdjecia", null)
                } else {
                    startBillScan(scanId, path, result)
                }
            }
            "drainScanResults" -> result.success(
                mapOf(
                    "results" to ScanResultStore.drain(context),
                    "inFlight" to ScanResultStore.inFlightIds(),
                ),
            )
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
        val intent = context.packageManager.getLaunchIntentForPackage(EngineClient.ENGINE_PACKAGE)
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
        if (!EngineClient.isInstalled(context)) {
            result.success(
                mapOf("installed" to false, "modelReady" to false, "modelLoaded" to false),
            )
            return
        }
        EngineClient.withEngine(
            context,
            workTimeoutMs = EngineClient.STATUS_TIMEOUT_MS,
            onConnected = { engine, finish ->
                val ready = engine.isModelReady
                val loaded = engine.isModelLoaded
                finish {
                    result.success(
                        mapOf("installed" to true, "modelReady" to ready, "modelLoaded" to loaded),
                    )
                }
            },
            onFailure = { code, message -> result.error(code, message, null) },
        )
    }

    /**
     * Zleca rozpoznanie rachunku i wraca od razu - wynik przyjdzie skrzynka
     * [ScanResultStore]. Normalnie prace prowadzi [BillScanService]; gdy system
     * odmowi startu uslugi (Android 12+ blokuje start z tla), skanujemy po
     * staremu w procesie apki - gorzej chronione, ale lepsze niz nic.
     */
    private fun startBillScan(scanId: String, path: String, result: MethodChannel.Result) {
        val file = File(path)
        if (!file.exists()) {
            result.error("BAD_INPUT", "Plik zdjecia nie istnieje: $path", null)
            return
        }
        if (BillScanService.start(context, scanId, path)) {
            result.success(true)
            return
        }
        ScanResultStore.markInFlight(scanId)
        ScanNotifications.showProgress(context)
        scanInProcess(scanId, file)
        result.success(true)
    }

    /** Awaryjna sciezka: bind i OCR bez uslugi pierwszoplanowej. */
    private fun scanInProcess(scanId: String, file: File) {
        fun complete(json: String?, code: String?, message: String?) {
            ScanNotifications.cancelProgress(context)
            val handledByApp = ScanResultStore.complete(context, scanId, json, code, message)
            if (!handledByApp) ScanNotifications.showTerminal(context, scanId, json != null)
        }

        val mime = when (file.extension.lowercase()) {
            "png" -> "image/png"
            "webp" -> "image/webp"
            "gif" -> "image/gif"
            else -> "image/jpeg"
        }
        EngineClient.withEngine(
            context,
            workTimeoutMs = EngineClient.SCAN_TIMEOUT_MS,
            onConnected = { engine, finish ->
                val cb = object : IAiCallback.Stub() {
                    override fun onResult(json: String?) {
                        finish { complete(json ?: "", null, null) }
                    }

                    override fun onError(code: String?, message: String?) {
                        finish { complete(null, code ?: "ENGINE_ERROR", message) }
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
            onFailure = { code, message -> complete(null, code, message) },
        )
    }

    companion object {
        const val CHANNEL = "zostaje/ai_engine"
    }
}
