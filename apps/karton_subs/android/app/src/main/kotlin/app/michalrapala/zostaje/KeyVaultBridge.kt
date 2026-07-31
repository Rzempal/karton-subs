package app.michalrapala.zostaje

import android.content.Context
import android.util.Log
import com.google.android.gms.auth.blockstore.Blockstore
import com.google.android.gms.auth.blockstore.BlockstoreClient
import com.google.android.gms.auth.blockstore.RetrieveBytesRequest
import com.google.android.gms.auth.blockstore.StoreBytesData
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Sejf na kod odzyskiwania kopii zapasowych (Block Store z uslug Google Play).
 *
 * Kod wedruje na nowy telefon razem z systemowym przenoszeniem danych - uzytkownik
 * nie musi go nigdzie zapisywac. Sejf jest DODATKIEM, nie zrodlem prawdy:
 * zrodlem pozostaje flutter_secure_storage, a kazdy blad tutaj konczy sie
 * cichym "brak" zamiast wyjatku (telefony bez uslug Google maja dzialac dalej).
 *
 * Zapis do chmury wymaga szyfrowania E2E po stronie Google: Android 9+ oraz
 * ustawionej blokady ekranu. Bez tego zapisujemy tylko lokalnie.
 *
 * Port z APPteczka (ADR-012).
 */
class KeyVaultBridge(private val context: Context) {

    private val client: BlockstoreClient? by lazy {
        runCatching { Blockstore.getClient(context) }
            .onFailure { Log.i(TAG, "Block Store niedostepny: ${it.message}") }
            .getOrNull()
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isCloudBackupAvailable" -> isCloudBackupAvailable(result)
            "saveRecoveryCode" -> saveRecoveryCode(call.argument<String>("code"), result)
            "readRecoveryCode" -> readRecoveryCode(result)
            else -> result.notImplemented()
        }
    }

    /** Czy kod da sie zapisac na koncie Google (E2E dostepne). Kazdy problem -> false. */
    private fun isCloudBackupAvailable(result: MethodChannel.Result) {
        val client = client ?: return result.success(false)
        client.isEndToEndEncryptionAvailable
            .addOnSuccessListener { available ->
                Log.i(TAG, "isCloudBackupAvailable=$available")
                result.success(available)
            }
            .addOnFailureListener {
                Log.i(TAG, "isCloudBackupAvailable=false (${it.message})")
                result.success(false)
            }
    }

    /**
     * Zapisuje kod w sejfie. Zwraca true, gdy trafil takze do chmury Google
     * (czyli przetrwa wymiane telefonu), false gdy zapis byl tylko lokalny.
     *
     * UWAGA: flaga kopii w chmurze musi byc ustawiona przy KAZDYM zapisie -
     * zapis bez niej kasuje to, co juz jest w chmurze.
     */
    private fun saveRecoveryCode(code: String?, result: MethodChannel.Result) {
        val client = client ?: return result.success(false)
        if (code.isNullOrEmpty()) {
            return result.error("BAD_INPUT", "Pusty kod odzyskiwania", null)
        }

        client.isEndToEndEncryptionAvailable
            .addOnSuccessListener { toCloud -> store(client, code, toCloud, result) }
            .addOnFailureListener { store(client, code, false, result) }
    }

    /** Kod z sejfu albo null, gdy sejf pusty lub niedostepny. */
    private fun readRecoveryCode(result: MethodChannel.Result) {
        val client = client ?: return result.success(null)
        val request = RetrieveBytesRequest.Builder()
            .setKeys(listOf(KEY))
            .build()

        client.retrieveBytes(request)
            .addOnSuccessListener { response ->
                val bytes = response.blockstoreDataMap[KEY]?.bytes
                Log.i(TAG, "readRecoveryCode: ${if (bytes == null) "pusto" else "znaleziono"}")
                result.success(bytes?.toString(Charsets.UTF_8))
            }
            .addOnFailureListener {
                Log.i(TAG, "readRecoveryCode: blad (${it.message})")
                result.success(null)
            }
    }

    private fun store(
        client: BlockstoreClient,
        code: String,
        toCloud: Boolean,
        result: MethodChannel.Result,
    ) {
        val data = StoreBytesData.Builder()
            .setBytes(code.toByteArray(Charsets.UTF_8))
            .setKey(KEY)
            .setShouldBackupToCloud(toCloud)
            .build()

        client.storeBytes(data)
            .addOnSuccessListener {
                Log.i(TAG, "saveRecoveryCode OK (chmura=$toCloud)")
                result.success(toCloud)
            }
            .addOnFailureListener {
                Log.i(TAG, "saveRecoveryCode blad: ${it.message}")
                result.success(false)
            }
    }

    companion object {
        const val CHANNEL = "app.zostaje/key_vault"
        private const val TAG = "KeyVault"
        private const val KEY = "zostaje_backup_recovery_code"
    }
}
