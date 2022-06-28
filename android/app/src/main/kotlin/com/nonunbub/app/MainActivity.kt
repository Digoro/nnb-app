package com.nonunbub.app

import android.content.Intent
import android.content.Intent.URI_INTENT_SCHEME
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "NNB/INTENT").setMethodCallHandler {
                call, result ->
            if (call.method == "intent") {
                val url = call.argument<String>("url");
                val intent = Intent.parseUri(url, URI_INTENT_SCHEME);
                // 실행 가능한 앱이 있으면 앱 실행
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    result.success(null);
                } else {
                    // Fallback URL이 있으면 현재 웹뷰에 로딩
                    val fallbackUrl = intent.getStringExtra("browser_fallback_url")
                    if (fallbackUrl != null) {
                        result.success(fallbackUrl);
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }
}