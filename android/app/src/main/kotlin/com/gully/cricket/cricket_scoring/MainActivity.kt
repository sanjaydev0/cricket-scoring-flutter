package com.gully.cricket.cricket_scoring

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Thin FlutterActivity. All backup logic lives in [BackupBridge]; this class
 * only wires the channel and forwards activity results.
 */
class MainActivity : FlutterActivity() {
    private lateinit var bridge: BackupBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = BackupBridge(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BackupBridge.CHANNEL)
            .setMethodCallHandler { call, result -> bridge.handle(call, result) }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (bridge.onActivityResult(requestCode, resultCode, data)) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}