package app.michalrapala.zostaje

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import kotlin.math.absoluteValue

/**
 * Powiadomienia skanowania po stronie natywnej. Kanal jest ten sam, co po
 * stronie Dart (`zostaje_scan`), wiec uzytkownik widzi jedno miejsce
 * w ustawieniach powiadomien.
 *
 * Podzial obowiazkow: postep pokazuje usluga pierwszoplanowa (bez niego
 * Android nie pozwala jej dzialac), a powiadomienie koncowe wystawia ta
 * strona, ktora zyje w chwili zakonczenia - Dart (z nazwa rachunku) albo
 * natywna (ogolne), gdy warstwa Flutter zostala juz ubita.
 */
object ScanNotifications {

    const val CHANNEL_ID = "zostaje_scan"
    private const val CHANNEL_NAME = "Skanowanie rachunków"

    /** Staly identyfikator powiadomienia uslugi pierwszoplanowej. */
    const val PROGRESS_ID = 899_001

    fun progressNotification(context: Context): Notification {
        ensureChannel(context)
        return baseBuilder(context)
            .setContentTitle("Rozpoznaję rachunek…")
            .setContentText("Lokalny silnik AI pracuje w tle (ok. 1 min)")
            .setProgress(0, 0, true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    /** Postep dla awaryjnej sciezki bez uslugi (skan w procesie apki). */
    fun showProgress(context: Context) {
        manager(context).notify(PROGRESS_ID, progressNotification(context))
    }

    fun cancelProgress(context: Context) {
        manager(context).cancel(PROGRESS_ID)
    }

    /** Powiadomienie koncowe dla skanu, ktorego nie odebrala juz warstwa Dart. */
    fun showTerminal(context: Context, scanId: String, success: Boolean) {
        ensureChannel(context)
        val notification = baseBuilder(context)
            .setContentTitle(
                if (success) "Rachunek rozpoznany — gotowe" else "Nie udało się rozpoznać rachunku",
            )
            .setContentText(
                if (success) {
                    "Czeka na zatwierdzenie w zakładce Rachunki"
                } else {
                    "Otwórz zakładkę Rachunki, by ponowić lub uzupełnić ręcznie"
                },
            )
            .setContentIntent(openAppIntent(context))
            .setAutoCancel(true)
            .build()
        manager(context).notify(terminalId(scanId), notification)
    }

    private fun baseBuilder(context: Context): Notification.Builder {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        return builder.setSmallIcon(R.mipmap.ic_launcher)
    }

    private fun openAppIntent(context: Context): PendingIntent? {
        val intent = context.packageManager
            .getLaunchIntentForPackage(context.packageName) ?: return null
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        ).apply { description = "Postęp rozpoznawania rachunków ze zdjęć" }
        manager(context).createNotificationChannel(channel)
    }

    private fun manager(context: Context): NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    /** Zakres identyfikatorow wspolny z warstwa Dart (jeden skan = jedno miejsce). */
    private fun terminalId(scanId: String): Int =
        900_000 + (scanId.hashCode().absoluteValue % 90_000)
}
