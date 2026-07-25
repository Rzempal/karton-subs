package app.michalrapala.zostaje

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Skrzynka na wyniki rozpoznawania rachunkow: usluga wrzuca, warstwa Dart
 * odbiera. Wynik ZAWSZE trafia na dysk i znika dopiero przy odbiorze - dzieki
 * temu skan konczy sie poprawnie takze wtedy, gdy w miedzyczasie system ubil
 * warstwe Flutter (np. zmiecenie apki z listy ostatnich w trakcie OCR).
 *
 * [inFlight] zyje tylko w pamieci procesu: gdy proces zginie, "trwajace" skany
 * przestaja istniec i Dart oznaczy je jako bledne (do ponowienia) - dokladnie
 * to, co sie z nimi faktycznie stalo.
 */
object ScanResultStore {

    private const val PREFS = "zostaje_scan_results"
    private const val KEY_RESULTS = "results"

    private val inFlight = linkedSetOf<String>()

    /** Ping do warstwy Dart („sa nowe wyniki") - null, gdy Flutter nie zyje. */
    private var listener: (() -> Unit)? = null

    @Synchronized
    fun setListener(cb: (() -> Unit)?) {
        listener = cb
    }

    @Synchronized
    fun markInFlight(scanId: String) {
        inFlight.add(scanId)
    }

    @Synchronized
    fun inFlightIds(): List<String> = inFlight.toList()

    /**
     * Zapisuje wynik skanu i budzi warstwe Dart. Zwraca `true`, gdy Flutter
     * zyje i sam pokaze powiadomienie o zakonczeniu; `false` = powiadomienie
     * musi wystawic strona natywna.
     */
    @Synchronized
    fun complete(
        context: Context,
        scanId: String,
        json: String?,
        errorCode: String?,
        errorMessage: String?,
    ): Boolean {
        inFlight.remove(scanId)
        val live = listener != null
        val record = JSONObject()
            .put("scanId", scanId)
            .put("json", json ?: JSONObject.NULL)
            .put("errorCode", errorCode ?: JSONObject.NULL)
            .put("errorMessage", errorMessage ?: JSONObject.NULL)
            .put("nativeNotified", !live)
        append(context, record)
        listener?.invoke()
        return live
    }

    /** Oddaje wszystkie odlozone wyniki i czysci skrzynke (odbior jednorazowy). */
    @Synchronized
    fun drain(context: Context): List<Map<String, Any?>> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_RESULTS, null) ?: return emptyList()
        prefs.edit().remove(KEY_RESULTS).apply()
        val array = runCatching { JSONArray(raw) }.getOrNull() ?: return emptyList()
        val out = mutableListOf<Map<String, Any?>>()
        for (i in 0 until array.length()) {
            val o = array.optJSONObject(i) ?: continue
            out.add(
                mapOf(
                    "scanId" to o.optString("scanId"),
                    "json" to o.optStringOrNull("json"),
                    "errorCode" to o.optStringOrNull("errorCode"),
                    "errorMessage" to o.optStringOrNull("errorMessage"),
                    "nativeNotified" to o.optBoolean("nativeNotified", false),
                ),
            )
        }
        return out
    }

    private fun append(context: Context, record: JSONObject) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val current = runCatching { JSONArray(prefs.getString(KEY_RESULTS, "[]")) }
            .getOrDefault(JSONArray())
        current.put(record)
        // commit zamiast apply: wynik ma przezyc natychmiastowe ubicie procesu.
        prefs.edit().putString(KEY_RESULTS, current.toString()).commit()
    }

    private fun JSONObject.optStringOrNull(key: String): String? =
        if (isNull(key)) null else optString(key).takeIf { it.isNotEmpty() }
}
