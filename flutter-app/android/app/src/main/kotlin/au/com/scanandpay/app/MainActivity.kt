package au.com.scanandpay.app

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "au.com.scanandpay.app/second_screen"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    result.success(SecondScreenHelper.initialize())
                }
                "showQR" -> {
                    val qrBytes = call.argument<ByteArray>("qrImage")
                    val title = call.argument<String>("title")
                    val amount = call.argument<String>("amount")
                    if (qrBytes != null) {
                        SecondScreenHelper.showFromByteArray(applicationContext, qrBytes, title, amount)
                        result.success(true)
                    } else {
                        result.error("INVALID", "QR image is null", null)
                    }
                }
                "showMessage" -> {
                    val message = call.argument<String>("message") ?: ""
                    SecondScreenHelper.showMessage(message)
                    result.success(true)
                }
                "clear" -> {
                    SecondScreenHelper.clear()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        SecondScreenHelper.initialize()
    }

    override fun onDestroy() {
        super.onDestroy()
        SecondScreenHelper.close()
    }
}
