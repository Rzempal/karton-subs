package app.michalrapala.zostaje

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import app.michalrapala.ai_engine.IAiEngine
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Wspolny dostep do uslugi AIDL Lokalnego Silnika AI: bind -> praca -> unbind.
 * Uzywa go i mostek (status silnika), i usluga skanujaca (rozpoznawanie).
 *
 * ZAWSZE pakiet PRODUKCYJNY silnika (app.michalrapala.ai_engine) - takze
 * w buildzie dev Zostaje (ADR-013).
 */
object EngineClient {

    /** Pakiet PRODUKCYJNY silnika - jedyny, do ktorego binduja klienci. */
    const val ENGINE_PACKAGE = "app.michalrapala.ai_engine"
    private const val BIND_ACTION = "app.michalrapala.ai_engine.BIND"

    /**
     * Limit na samo wpiecie sie do uslugi (osobny od czasu pracy silnika):
     * z zapasem na zimny start procesu silnika. Bez tego rozdzielenia
     * nieudany bind wygladalby jak trzyminutowe zawieszenie.
     */
    const val CONNECT_TIMEOUT_MS = 25_000L

    /** Odpytanie o stan modelu jest natychmiastowe. */
    const val STATUS_TIMEOUT_MS = 10_000L

    /** OCR na CPU trwa ~30-45 s + ewentualne ladowanie modelu (~10 s). */
    const val SCAN_TIMEOUT_MS = 180_000L

    fun isInstalled(context: Context): Boolean =
        runCatching { context.packageManager.getPackageInfo(ENGINE_PACKAGE, 0) }.isSuccess

    /**
     * Cykl: bind -> [onConnected] -> unbind (przez `finish`, dokladnie raz).
     * Blad bindowania, brak polaczenia w [CONNECT_TIMEOUT_MS], przekroczenie
     * [workTimeoutMs] i rozlaczenie uslugi konczy wywolanie przez [onFailure].
     *
     * [important] podnosi priorytet procesu silnika do priorytetu klienta -
     * uzywane przez usluge pierwszoplanowa, zeby system nie zdlawil silnika
     * w trakcie wnioskowania (model zjada kilka GB pamieci).
     */
    fun withEngine(
        context: Context,
        workTimeoutMs: Long,
        important: Boolean = false,
        onConnected: (IAiEngine, finish: (block: () -> Unit) -> Unit) -> Unit,
        onFailure: (code: String, message: String) -> Unit,
    ) {
        val main = Handler(Looper.getMainLooper())
        val done = AtomicBoolean(false)
        var connRef: ServiceConnection? = null
        var pendingTimeout: Runnable? = null

        fun finish(block: () -> Unit) {
            if (done.compareAndSet(false, true)) {
                main.post {
                    pendingTimeout?.let { main.removeCallbacks(it) }
                    connRef?.let { runCatching { context.unbindService(it) } }
                    block()
                }
            }
        }

        val conn = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                // Od tej chwili liczy sie czas pracy silnika, nie laczenia.
                pendingTimeout?.let { main.removeCallbacks(it) }
                val workTimeout = Runnable {
                    finish {
                        onFailure(
                            "TIMEOUT",
                            "Silnik nie odpowiedzial w czasie ${workTimeoutMs / 1000} s",
                        )
                    }
                }
                pendingTimeout = workTimeout
                main.postDelayed(workTimeout, workTimeoutMs)
                try {
                    onConnected(IAiEngine.Stub.asInterface(binder), ::finish)
                } catch (t: Throwable) {
                    finish { onFailure("ENGINE_ERROR", t.message ?: "Blad silnika") }
                }
            }

            override fun onServiceDisconnected(name: ComponentName?) {
                finish { onFailure("ENGINE_DISCONNECTED", "Usluga silnika rozlaczona") }
            }
        }
        connRef = conn

        val intent = Intent(BIND_ACTION)
            .setPackage(ENGINE_PACKAGE)
            // Apka silnika bywa w stanie "zatrzymana": swieza instalacja, "wymus
            // zatrzymanie" albo uspienie nieuzywanej apki przez system. Bez tej
            // flagi Android nie dopasuje jej komponentow i bind nie dochodzi do
            // skutku - trzeba bylo recznie odpalac silnik przed skanem.
            .addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
        var flags = Context.BIND_AUTO_CREATE
        if (important) flags = flags or Context.BIND_IMPORTANT

        val bound = runCatching { context.bindService(intent, conn, flags) }.getOrDefault(false)
        if (!bound) {
            // bindService rejestruje polaczenie takze przy wyniku false.
            finish {
                onFailure(
                    "ENGINE_NOT_INSTALLED",
                    "Nie mozna wpiac sie do Lokalnego Silnika AI - zainstaluj apke silnika",
                )
            }
            return
        }
        val connectTimeout = Runnable {
            finish {
                onFailure(
                    "ENGINE_UNAVAILABLE",
                    "Lokalny Silnik AI nie odpowiada - otworz apke silnika i sprobuj ponownie",
                )
            }
        }
        pendingTimeout = connectTimeout
        main.postDelayed(connectTimeout, CONNECT_TIMEOUT_MS)
    }
}
