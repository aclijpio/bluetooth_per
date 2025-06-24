package pio.aclij.bluetooth_per

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bluetooth_per/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openFolder" -> {
                        // Пока просто возвращаем успех, чтобы не блокировать клиент.
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
