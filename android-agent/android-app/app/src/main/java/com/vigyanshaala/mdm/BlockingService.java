package com.vigyanshaala.mdm;

import android.app.Service;
import android.content.Intent;
import android.content.pm.PackageInstaller;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public class BlockingService extends Service {
    private SupabaseClient supabaseClient;
    private ScheduledExecutorService scheduler;
    private Handler mainHandler;
    
    @Override
    public void onCreate() {
        super.onCreate();
        supabaseClient = new SupabaseClient(this);
        mainHandler = new Handler(Looper.getMainLooper());
        
        // Schedule periodic syncs
        scheduler = Executors.newScheduledThreadPool(2);
        
        // Sync website blocklist every 30 minutes
        scheduler.scheduleAtFixedRate(this::syncWebsiteBlocklist, 0, 30, TimeUnit.MINUTES);
        
        // Sync software blocklist every hour
        scheduler.scheduleAtFixedRate(this::syncSoftwareBlocklist, 0, 1, TimeUnit.HOURS);
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        return START_STICKY; // Restart service if killed
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
    
    private void syncWebsiteBlocklist() {
        new Thread(() -> {
            try {
                JSONArray blocklist = supabaseClient.getWebsiteBlocklist();
                List<String> domains = new ArrayList<>();
                
                for (int i = 0; i < blocklist.length(); i++) {
                    JSONObject item = blocklist.getJSONObject(i);
                    String domain = item.getString("domain_pattern");
                    domains.add(domain);
                }
                
                // Apply website blocking (via Private DNS or VPN)
                // Implementation depends on Android version and available APIs
                applyWebsiteBlocking(domains);
                
            } catch (Exception e) {
                e.printStackTrace();
            }
        }).start();
    }
    
    private void syncSoftwareBlocklist() {
        new Thread(() -> {
            try {
                JSONArray blocklist = supabaseClient.getSoftwareBlocklist();
                List<String> blockedApps = new ArrayList<>();
                
                for (int i = 0; i < blocklist.length(); i++) {
                    JSONObject item = blocklist.getJSONObject(i);
                    String namePattern = item.getString("name_pattern");
                    blockedApps.add(namePattern);
                }
                
                // Check and uninstall blocked apps
                checkAndRemoveBlockedApps(blockedApps);
                
            } catch (Exception e) {
                e.printStackTrace();
            }
        }).start();
    }
    
    private void applyWebsiteBlocking(List<String> domains) {
        // Note: Android website blocking requires:
        // - Private DNS API (Android 9+)
        // - Or VPN API with DNS filtering
        // This is a placeholder - full implementation requires more complex setup
    }
    
    private void checkAndRemoveBlockedApps(List<String> blockedPatterns) {
        PackageManager pm = getPackageManager();
        
        // Note: Uninstalling apps requires Device Admin permissions
        // This is a simplified version - full implementation needs proper Device Admin setup
        
        try {
            // This would iterate through installed apps and check against blocklist
            // Then uninstall matching apps using PackageInstaller API
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    
    @Override
    public void onDestroy() {
        super.onDestroy();
        if (scheduler != null) {
            scheduler.shutdown();
        }
    }
}

