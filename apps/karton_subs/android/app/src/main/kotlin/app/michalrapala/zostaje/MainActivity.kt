package app.michalrapala.zostaje

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Mostek do Lokalnego Silnika AI (OCR rachunkow przez usluge AIDL silnika).
        val bridge = AiEngineBridge(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AiEngineBridge.CHANNEL)
            .setMethodCallHandler(bridge::handle)
    }
}
