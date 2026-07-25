package app.michalrapala.zostaje

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var bridge: AiEngineBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Mostek do Lokalnego Silnika AI (OCR rachunkow przez usluge AIDL silnika).
        val bridge = AiEngineBridge(applicationContext)
        val channel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AiEngineBridge.CHANNEL)
        channel.setMethodCallHandler(bridge::handle)
        // Kanal w obie strony: warstwa natywna zglasza gotowe wyniki skanow.
        bridge.attach(channel)
        this.bridge = bridge
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Bez odpiecia usluga skanujaca trzymalaby martwy kanal; wyniki i tak
        // czekaja w skrzynce do nastepnego uruchomienia apki.
        bridge?.detach()
        bridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
