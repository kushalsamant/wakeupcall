package com.kushal.wakeupcall;

import android.os.Bundle;
import android.view.WindowManager;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.widget.Button;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;

public class CallActivity extends AppCompatActivity {
    private Ringtone ringtone;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_call);

        // Show on lock screen
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON |
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD |
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED |
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);

        // Play ringtone
        ringtone = RingtoneManager.getRingtone(this, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE));
        if (ringtone != null) {
            ringtone.play();
        }

        // UI elements
        TextView callerText = findViewById(R.id.caller_text);
        callerText.setText("Incoming WakeUpCall");
        Button acceptButton = findViewById(R.id.accept_button);
        Button declineButton = findViewById(R.id.decline_button);

        acceptButton.setOnClickListener(v -> finish());
        declineButton.setOnClickListener(v -> finish());
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (ringtone != null && ringtone.isPlaying()) {
            ringtone.stop();
        }
    }
}
