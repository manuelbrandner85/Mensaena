package de.mensaena.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/// Punkt 11: Foreground-Service damit Livestream-/Call-Audio weiterläuft
/// wenn die App minimiert ist oder der Bildschirm aus geht.
/// Typ = microphone (Permission FOREGROUND_SERVICE_MICROPHONE im Manifest).
/// Wird von MainActivity über den MethodChannel de.mensaena.app/audio
/// gestartet/gestoppt (start beim Room-Connect, stop beim Verlassen).
class LiveAudioService : Service() {
    companion object {
        const val CHANNEL_ID = "mensaena_live_audio"
        const val NOTIF_ID = 7711
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        val notif: Notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Mensæna")
            .setContentText("Live-Audio aktiv")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .build()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIF_ID,
                    notif,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                )
            } else {
                startForeground(NOTIF_ID, notif)
            }
        } catch (e: Exception) {
            // Wenn der Foreground-Start scheitert (z.B. fehlende Notif-Perm),
            // den Service sauber beenden statt zu crashen.
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                mgr.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Live-Audio",
                        NotificationManager.IMPORTANCE_LOW
                    )
                )
            }
        }
    }
}
