package com.kushal.wakeupcall;

import android.content.Intent;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.os.Bundle;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;

public class CallActivity extends AppCompatActivity {
    private Ringtone ringtone;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_call);

        // Show over lock screen
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED |
                             WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON |
                             WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        // Play ringtone
        ringtone = RingtoneManager.getRingtone(this, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE));
        ringtone.play();

        // Set wake-up time
        String wakeupTime = getIntent().getStringExtra("wakeupTime");
        TextView timeView = findViewById(R.id.call_time);
        timeView.setText("Wake-Up Call: " + (wakeupTime != null ? wakeupTime : "Now"));

        // Accept button
        Button acceptButton = findViewById(R.id.accept_button);
        acceptButton.setOnClickListener(v -> finish());

        // Decline button
        Button declineButton = findViewById(R.id.decline_button);
        declineButton.setOnClickListener(v -> finish());
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (ringtone != null && ringtone.isPlaying()) {
            ringtone.stop();
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        String wakeupTime = intent.getStringExtra("wakeupTime");
        TextView timeView = findViewById(R.id.call_time);
        timeView.setText("Wake-Up Call: " + (wakeupTime != null ? wakeupTime : "Now"));
    }
}