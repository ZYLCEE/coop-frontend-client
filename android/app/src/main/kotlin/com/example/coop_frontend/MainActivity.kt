package com.example.coop_frontend

import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
	private val channelName = "coop_frontend/security"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"enableSecureWindow" -> {
						window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
						result.success(null)
					}
					else -> result.notImplemented()
				}
			}
	}
}
