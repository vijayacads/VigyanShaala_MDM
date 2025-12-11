package com.vigyanshaala.mdm;

import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;

public class SupabaseClient {
    private static final String PREFS_NAME = "mdm_prefs";
    private static final String KEY_URL = "supabase_url";
    private static final String KEY_API = "supabase_api_key";
    
    private Context context;
    private String baseUrl;
    private String apiKey;
    
    public SupabaseClient(Context context) {
        this.context = context;
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        this.baseUrl = prefs.getString(KEY_URL, "");
        this.apiKey = prefs.getString(KEY_API, "");
    }
    
    public void setCredentials(String url, String apiKey) {
        this.baseUrl = url;
        this.apiKey = apiKey;
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        prefs.edit()
            .putString(KEY_URL, url)
            .putString(KEY_API, apiKey)
            .apply();
    }
    
    public boolean registerDevice(JSONObject deviceData) {
        try {
            URL url = new URL(baseUrl + "/rest/v1/devices");
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("apikey", apiKey);
            conn.setRequestProperty("Authorization", "Bearer " + apiKey);
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setRequestProperty("Prefer", "return=representation");
            conn.setDoOutput(true);
            
            OutputStream os = conn.getOutputStream();
            os.write(deviceData.toString().getBytes("UTF-8"));
            os.flush();
            os.close();
            
            int responseCode = conn.getResponseCode();
            return responseCode >= 200 && responseCode < 300;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
    
    public JSONArray getWebsiteBlocklist() {
        try {
            URL url = new URL(baseUrl + "/rest/v1/website_blocklist?is_active=eq.true&select=domain_pattern");
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setRequestProperty("apikey", apiKey);
            conn.setRequestProperty("Authorization", "Bearer " + apiKey);
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
            StringBuilder response = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                response.append(line);
            }
            reader.close();
            
            return new JSONArray(response.toString());
        } catch (Exception e) {
            e.printStackTrace();
            return new JSONArray();
        }
    }
    
    public JSONArray getSoftwareBlocklist() {
        try {
            URL url = new URL(baseUrl + "/rest/v1/software_blocklist?is_active=eq.true&select=name_pattern,path_pattern");
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setRequestProperty("apikey", apiKey);
            conn.setRequestProperty("Authorization", "Bearer " + apiKey);
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
            StringBuilder response = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                response.append(line);
            }
            reader.close();
            
            return new JSONArray(response.toString());
        } catch (Exception e) {
            e.printStackTrace();
            return new JSONArray();
        }
    }
}

