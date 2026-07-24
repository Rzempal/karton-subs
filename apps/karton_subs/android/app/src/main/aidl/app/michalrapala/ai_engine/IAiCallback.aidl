// DUPLIKAT kontraktu z repo karton-ai (app/src/main/aidl/...) - musi byc IDENTYCZNY.
package app.michalrapala.ai_engine;

/** Odpowiedz silnika do apki-klienta (asynchronicznie). */
interface IAiCallback {
    /** Sukces: surowy tekst JSON wyniku OCR. */
    oneway void onResult(String json);

    /** Blad: kod (np. MODEL_MISSING, INFERENCE_ERROR) + opis. */
    oneway void onError(String code, String message);
}
