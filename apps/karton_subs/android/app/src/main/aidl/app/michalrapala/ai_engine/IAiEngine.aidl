// DUPLIKAT kontraktu z repo karton-ai (app/src/main/aidl/...) - musi byc IDENTYCZNY.
// Zmiany kontraktu robi silnik (nowe metody TYLKO na koncu interfejsu); klient kopiuje.
package app.michalrapala.ai_engine;

import app.michalrapala.ai_engine.IAiCallback;

/**
 * Kontrakt uslugi wnioskowania udostepnianej innym apkom (Mechanizm 2).
 * Obraz przekazywany przez ParcelFileDescriptor (limit ~1 MB na zwykle
 * wywolanie Bindera - bajtow nie wysylamy w tresci).
 */
interface IAiEngine {
    /** Czy plik modelu jest na urzadzeniu i gotowy do zaladowania. */
    boolean isModelReady();

    /**
     * Rozpoznaje leki ze zdjecia. Wynik (JSON) wraca przez [callback].
     * @param image  uchwyt do pliku zdjecia (tryb do odczytu)
     * @param mimeType np. "image/jpeg"
     */
    oneway void recognizeImage(in ParcelFileDescriptor image, String mimeType, IAiCallback callback);

    /**
     * Czy model jest WCZYTANY do pamieci (gotowy do natychmiastowego wnioskowania).
     * Dodane na koncu interfejsu, by nie zmieniac ID transakcji powyzszych metod.
     */
    boolean isModelLoaded();

    /**
     * Rozpoznaje rachunek/fakture ze zdjecia (klient: Zostaje). Wynik (JSON
     * {"rachunki":[...]}) wraca przez [callback]. Dodane na koncu interfejsu,
     * by nie zmieniac ID transakcji powyzszych metod.
     * @param image  uchwyt do pliku zdjecia (tryb do odczytu)
     * @param mimeType np. "image/jpeg"
     */
    oneway void recognizeBill(in ParcelFileDescriptor image, String mimeType, IAiCallback callback);
}
