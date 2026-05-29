package de.mensaena.app

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// local_auth (F15) verlangt FragmentActivity statt FlutterActivity.
/// ZUSATZ-3 (PiP): MethodChannel `de.mensaena.app/pip` mit
///   - enterPip([w,h]) → ruft enterPictureInPictureMode mit Aspect-Ratio
///   - exitPip() → moveTaskToBack (System schließt PiP automatisch)
/// Außerdem: onPictureInPictureModeChanged pusht den State an Flutter
/// damit das UI sich anpasst (z.B. Controls verstecken im PiP-Modus).
class MainActivity : FlutterFragmentActivity() {
    private val pipChannel = "de.mensaena.app/pip"
    private val audioChannel = "de.mensaena.app/audio"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, pipChannel
        )
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> result.success(enterPip(call))
                "isPipSupported" -> result.success(isPipSupported())
                else -> result.notImplemented()
            }
        }
        // Punkt 11: Foreground-Audio-Service für Hintergrund-/Screen-off-Audio.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, audioChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startAudioService()
                    result.success(true)
                }
                "stop" -> {
                    stopAudioService()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startAudioService() {
        try {
            val intent = android.content.Intent(this, LiveAudioService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            // Service-Start darf das App-UI nie crashen.
        }
    }

    private fun stopAudioService() {
        try {
            stopService(
                android.content.Intent(this, LiveAudioService::class.java)
            )
        } catch (e: Exception) {
        }
    }

    private fun isPipSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return packageManager.hasSystemFeature(
            android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE
        )
    }

    private fun enterPip(call: io.flutter.plugin.common.MethodCall): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val w = (call.argument<Int>("width") ?: 16).coerceIn(1, 100)
        val h = (call.argument<Int>("height") ?: 9).coerceIn(1, 100)
        return try {
            enterPictureInPictureMode(
                PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(w, h))
                    .build()
            )
        } catch (e: IllegalStateException) {
            false
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        methodChannel?.invokeMethod(
            "onPipModeChanged",
            mapOf("inPip" to isInPictureInPictureMode)
        )
    }
}
