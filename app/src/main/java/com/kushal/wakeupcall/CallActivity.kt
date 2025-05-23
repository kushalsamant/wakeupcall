package com.kushal.wakeupcall

import android.content.Context
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Bundle
import android.os.Vibrator
import android.view.WindowManager
import android.widget.Button
import androidx.appcompat.app.AppCompatActivity
import android.util.Log

class CallActivity : AppCompatActivity() {
    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("CallActivity", "onCreate called")

        // Show activity over lock screen and turn screen on
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or // Keep screen on while this activity is visible
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD // Dismiss keyguard if unsecured
            )
        }
        // For full screen experience
        window.setFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS, WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)


        setContentView(R.layout.activity_call)
        Log.d("CallActivity", "Layout set")

        val acceptButton = findViewById<Button>(R.id.acceptButton)
        val declineButton = findViewById<Button>(R.id.declineButton)

        acceptButton.setOnClickListener {
            Log.d("CallActivity", "Accept button clicked")
            stopAlarm()
            finish()
        }

        declineButton.setOnClickListener {
            Log.d("CallActivity", "Decline button clicked")
            stopAlarm()
            finish()
        }

        playAlarm()
    }

    private fun playAlarm() {
        try {
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(this, ringtoneUri)
            ringtone?.let {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                    it.audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                }
                it.play()
                Log.d("CallActivity", "Ringtone playing")
            }

            // Vibrate
            vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (vibrator?.hasVibrator() == true) {
                val pattern = longArrayOf(0, 1000, 1000) // Vibrate for 1s, pause for 1s
                 if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    vibrator?.vibrate(android.os.VibrationEffect.createWaveform(pattern, 0)) // Repeat indefinitely
                 } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(pattern, 0)
                 }
                Log.d("CallActivity", "Vibrating")
            }
        } catch (e: Exception) {
            Log.e("CallActivity", "Error playing alarm", e)
        }
    }

    private fun stopAlarm() {
        ringtone?.stop()
        vibrator?.cancel()
        Log.d("CallActivity", "Alarm stopped")
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAlarm() // Ensure alarm stops if activity is destroyed
        Log.d("CallActivity", "onDestroy called, alarm stopped")
    }
}
