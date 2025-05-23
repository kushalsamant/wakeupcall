package com.kushal.wakeupcall

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.PowerManager
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        Log.d("AlarmReceiver", "Alarm received!")

        // Acquire a wake lock to ensure CPU is running
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "com.kushal.wakeupcall::WakeLockTag")
        wakeLock.acquire(10*60*1000L /*10 minutes*/) // Timeout for the wakelock

        try {
            val callIntent = Intent(context, CallActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP) // Ensures CallActivity is brought to front
            }
            context.startActivity(callIntent)
            Log.d("AlarmReceiver", "CallActivity started")
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error starting CallActivity", e)
        } finally {
            wakeLock.release() // Release the wake lock
            Log.d("AlarmReceiver", "WakeLock released")
        }
    }
}
