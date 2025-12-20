package com.vigyanshaala.mdm;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import org.json.JSONObject;

public class EnrollmentActivity extends AppCompatActivity {
    private static final String PREFS_NAME = "mdm_prefs";
    private SupabaseClient supabaseClient;
    
    private EditText etSupabaseUrl;
    private EditText etSupabaseKey;
    private EditText etHostname;
    private EditText etInventoryCode;
    private EditText etHostLocation;
    private EditText etCity;
    private EditText etLatitude;
    private EditText etLongitude;
    private EditText etAssignedTeacher;
    private EditText etAssignedStudentLeader;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_enrollment);
        
        supabaseClient = new SupabaseClient(this);
        
        // Initialize UI components
        etSupabaseUrl = findViewById(R.id.etSupabaseUrl);
        etSupabaseKey = findViewById(R.id.etSupabaseKey);
        etHostname = findViewById(R.id.etHostname);
        etInventoryCode = findViewById(R.id.etInventoryCode);
        etHostLocation = findViewById(R.id.etHostLocation);
        etCity = findViewById(R.id.etCity);
        etLatitude = findViewById(R.id.etLatitude);
        etLongitude = findViewById(R.id.etLongitude);
        etAssignedTeacher = findViewById(R.id.etAssignedTeacher);
        etAssignedStudentLeader = findViewById(R.id.etAssignedStudentLeader);
        
        Button btnRegister = findViewById(R.id.btnRegister);
        
        // Auto-fill device info
        etHostname.setText(android.os.Build.MODEL);
        
        btnRegister.setOnClickListener(v -> registerDevice());
    }
    
    private void registerDevice() {
        String supabaseUrl = etSupabaseUrl.getText().toString().trim();
        String supabaseKey = etSupabaseKey.getText().toString().trim();
        String hostname = etHostname.getText().toString().trim();
        String inventoryCode = etInventoryCode.getText().toString().trim();
        String hostLocation = etHostLocation.getText().toString().trim();
        
        // Validation
        if (supabaseUrl.isEmpty() || supabaseKey.isEmpty()) {
            Toast.makeText(this, "Please enter Supabase credentials", Toast.LENGTH_SHORT).show();
            return;
        }
        if (hostname.isEmpty() || inventoryCode.isEmpty() || hostLocation.isEmpty()) {
            Toast.makeText(this, "Please fill all required fields", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Set credentials
        supabaseClient.setCredentials(supabaseUrl, supabaseKey);
        
        // Prepare device data
        try {
            JSONObject deviceData = new JSONObject();
            deviceData.put("hostname", hostname);
            deviceData.put("device_inventory_code", inventoryCode);
            deviceData.put("host_location", hostLocation);
            
            String city = etCity.getText().toString().trim();
            if (!city.isEmpty()) deviceData.put("city_town_village", city);
            
            String latStr = etLatitude.getText().toString().trim();
            String lonStr = etLongitude.getText().toString().trim();
            if (!latStr.isEmpty() && !lonStr.isEmpty()) {
                deviceData.put("latitude", Double.parseDouble(latStr));
                deviceData.put("longitude", Double.parseDouble(lonStr));
            }
            
            String teacher = etAssignedTeacher.getText().toString().trim();
            if (!teacher.isEmpty()) deviceData.put("assigned_teacher", teacher);
            
            String studentLeader = etAssignedStudentLeader.getText().toString().trim();
            if (!studentLeader.isEmpty()) deviceData.put("assigned_student_leader", studentLeader);
            
            deviceData.put("serial_number", android.os.Build.SERIAL);
            deviceData.put("laptop_model", android.os.Build.MODEL);
            deviceData.put("os_version", android.os.Build.VERSION.RELEASE);
            deviceData.put("compliance_status", "unknown");
            
            // Register in background thread
            new Thread(() -> {
                boolean success = supabaseClient.registerDevice(deviceData);
                runOnUiThread(() -> {
                    if (success) {
                        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
                        prefs.edit()
                            .putBoolean("device_enrolled", true)
                            .putString("device_hostname", hostname)
                            .putString("supabase_url", supabaseUrl)
                            .putString("supabase_api_key", supabaseKey)
                            .apply();
                        
                        Toast.makeText(this, "Device enrolled successfully!", Toast.LENGTH_LONG).show();
                        finish();
                    } else {
                        Toast.makeText(this, "Enrollment failed. Check credentials and try again.", Toast.LENGTH_LONG).show();
                    }
                });
            }).start();
            
        } catch (Exception e) {
            e.printStackTrace();
            Toast.makeText(this, "Error: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }
}




