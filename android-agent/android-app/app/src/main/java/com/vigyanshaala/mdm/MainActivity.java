package com.vigyanshaala.mdm;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.widget.Button;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;

public class MainActivity extends AppCompatActivity {
    private static final String PREFS_NAME = "mdm_prefs";
    private static final String KEY_ENROLLED = "device_enrolled";
    private static final String KEY_HOSTNAME = "device_hostname";
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        boolean isEnrolled = prefs.getBoolean(KEY_ENROLLED, false);
        
        TextView statusText = findViewById(R.id.statusText);
        Button enrollButton = findViewById(R.id.enrollButton);
        
        if (isEnrolled) {
            String hostname = prefs.getString(KEY_HOSTNAME, "Unknown");
            statusText.setText("Device Enrolled\nHostname: " + hostname);
            enrollButton.setText("Re-enroll Device");
        } else {
            statusText.setText("Device Not Enrolled\nPlease enroll your device");
            enrollButton.setText("Enroll Device");
        }
        
        enrollButton.setOnClickListener(v -> {
            Intent intent = new Intent(MainActivity.this, EnrollmentActivity.class);
            startActivity(intent);
        });
        
        // Start blocking service if enrolled
        if (isEnrolled) {
            Intent serviceIntent = new Intent(this, BlockingService.class);
            startService(serviceIntent);
        }
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        boolean isEnrolled = prefs.getBoolean(KEY_ENROLLED, false);
        
        if (isEnrolled) {
            TextView statusText = findViewById(R.id.statusText);
            String hostname = prefs.getString(KEY_HOSTNAME, "Unknown");
            statusText.setText("Device Enrolled\nHostname: " + hostname);
        }
    }
}

