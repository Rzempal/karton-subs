package app.michalrapala.zostaje

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log
import app.michalrapala.ai_engine.IAiCallback
import java.io.File

/**
 * Usluga pierwszoplanowa prowadzaca rozpoznawanie rachunku (ADR-016).
 *
 * Po co usluga, skoro OCR i tak robi silnik: rozpoznawanie trwa ~45 s, a przez
 * ten czas silnik trzyma w pamieci model liczony w gigabajtach. Gdy uzytkownik
 * wyjdzie z Zostaje, zbuforowany proces apki jest pierwszym kandydatem do
 * ubicia wlasnie przez ten wzrost zapotrzebowania na pamiec - i skan przepadal.
 * Usluga pierwszoplanowa (z powiadomieniem "Rozpoznaje rachunek...") utrzymuje
 * proces przy zyciu, a [Context.BIND_IMPORTANT] podnosi priorytet silnika.
 *
 * Wynik trafia do [ScanResultStore], a nie prosto do Fluttera - dzieki temu
 * przezywa nawet ubicie warstwy Dart (zmiecenie apki z listy ostatnich).
 */
class BillScanService : Service() {

    private data class Job(val scanId: String, val imagePath: String)

    private val queue = ArrayDeque<Job>()
    private var busy = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Android wymaga wejscia na pierwszy plan tuz po starcie uslugi.
        goForeground()
        val scanId = intent?.getStringExtra(EXTRA_SCAN_ID)
        val imagePath = intent?.getStringExtra(EXTRA_IMAGE_PATH)
        if (scanId.isNullOrBlank() || imagePath.isNullOrBlank()) {
            if (!busy && queue.isEmpty()) stopSelf()
            return START_NOT_STICKY
        }
        queue.addLast(Job(scanId, imagePath))
        ScanResultStore.markInFlight(scanId)
        pump()
        // Bez wskrzeszania: po ubiciu procesu pozycja i tak wraca jako "ponow",
        // a wskrzeszona usluga nie mialaby komu oddac wyniku.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun goForeground() {
        val notification = ScanNotifications.progressNotification(this)
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    ScanNotifications.PROGRESS_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                startForeground(ScanNotifications.PROGRESS_ID, notification)
            }
        }.onFailure { Log.w(TAG, "startForeground", it) }
    }

    /** Jeden skan naraz - silnik i tak serializuje wnioskowanie. */
    private fun pump() {
        if (busy) return
        val job = queue.removeFirstOrNull()
        if (job == null) {
            stopSelf()
            return
        }
        busy = true
        runJob(job)
    }

    private fun runJob(job: Job) {
        val file = File(job.imagePath)
        if (!file.exists()) {
            finishJob(job, null, "BAD_INPUT", "Plik zdjecia nie istnieje")
            return
        }
        EngineClient.withEngine(
            context = this,
            workTimeoutMs = EngineClient.SCAN_TIMEOUT_MS,
            important = true,
            onConnected = { engine, finish ->
                val cb = object : IAiCallback.Stub() {
                    override fun onResult(json: String?) {
                        finish { finishJob(job, json ?: "", null, null) }
                    }

                    override fun onError(code: String?, message: String?) {
                        finish { finishJob(job, null, code ?: "ENGINE_ERROR", message) }
                    }
                }
                // Binder duplikuje deskryptor przy przekazaniu miedzy procesami;
                // wlasny uchwyt zamykamy od razu, silnik zamyka swoj.
                val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                try {
                    engine.recognizeBill(pfd, mimeFor(file), cb)
                } finally {
                    runCatching { pfd.close() }
                }
            },
            onFailure = { code, message -> finishJob(job, null, code, message) },
        )
    }

    private fun finishJob(job: Job, json: String?, errorCode: String?, errorMessage: String?) {
        val handledByApp = ScanResultStore.complete(
            applicationContext,
            job.scanId,
            json,
            errorCode,
            errorMessage,
        )
        // Gdy warstwa Flutter juz nie zyje, powiadomienie koncowe jest jedynym
        // sladem, ze skan sie skonczyl.
        if (!handledByApp) {
            ScanNotifications.showTerminal(applicationContext, job.scanId, json != null)
        }
        busy = false
        pump()
    }

    private fun mimeFor(file: File): String = when (file.extension.lowercase()) {
        "png" -> "image/png"
        "webp" -> "image/webp"
        "gif" -> "image/gif"
        else -> "image/jpeg"
    }

    companion object {
        private const val TAG = "BillScanService"
        private const val EXTRA_SCAN_ID = "scanId"
        private const val EXTRA_IMAGE_PATH = "imagePath"

        /**
         * Zleca rozpoznanie. `false` = systemu nie da sie o to poprosic (np.
         * Android 12+ blokuje start uslugi pierwszoplanowej, gdy apka jest juz
         * w tle) - wtedy mostek robi skan po staremu, w procesie apki.
         */
        fun start(context: Context, scanId: String, imagePath: String): Boolean {
            val intent = Intent(context, BillScanService::class.java)
                .putExtra(EXTRA_SCAN_ID, scanId)
                .putExtra(EXTRA_IMAGE_PATH, imagePath)
            return runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                true
            }.getOrElse {
                Log.w(TAG, "Nie mozna uruchomic uslugi skanowania", it)
                false
            }
        }
    }
}
