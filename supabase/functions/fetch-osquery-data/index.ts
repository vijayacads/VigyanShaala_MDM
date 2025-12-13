// Edge Function: Receive osquery data from FleetDM webhook
// Processes device data, software inventory, and web activity

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('Edge function invoked', { method: req.method, url: req.url })
    
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    const payload = await req.json()
    console.log('Payload received:', {
      has_hostname: !!payload.hostname,
      has_device_health: !!payload.device_health,
      has_battery_health: !!payload.battery_health,
      has_system_uptime: !!payload.system_uptime,
      device_health_count: payload.device_health?.length || 0,
      battery_health_count: payload.battery_health?.length || 0,
      system_uptime_count: payload.system_uptime?.length || 0
    })

    // Extract device info from osquery payload
    const hostname = payload.hostname || payload.host?.hostname

    if (!hostname) {
      console.error('Missing device hostname')
      return new Response(
        JSON.stringify({ error: 'Missing device hostname' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    console.log('Looking up device:', hostname)

    // Find device by hostname (hostname is now primary key after migration 008)
    const { data: device } = await supabaseClient
      .from('devices')
      .select('hostname, location_id')
      .eq('hostname', hostname)
      .single()

    if (!device) {
      return new Response(
        JSON.stringify({ error: 'Device not found. Please enroll device first.' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Update last_seen immediately when ANY data is received (heartbeat)
    const currentTime = new Date().toISOString()
    let hasData = false

    // Process WiFi network data for location tracking
    if (payload.wifi_networks && Array.isArray(payload.wifi_networks) && payload.wifi_networks.length > 0) {
      hasData = true
      const wifi = payload.wifi_networks[0]
      
      if (wifi.ssid && wifi.ssid.trim() !== '') {
        // Update device WiFi SSID
        await supabaseClient
          .from('devices')
          .update({
            wifi_ssid: wifi.ssid,
            last_seen: currentTime
          })
          .eq('hostname', device.hostname)

        // Try to match WiFi SSID to location
        // First, check if device has a location_id assigned
        if (device.location_id) {
          // Get location details
          const { data: location } = await supabaseClient
            .from('locations')
            .select('id, latitude, longitude, radius_meters')
            .eq('id', device.location_id)
            .single()

          if (location) {
            // Use location coordinates for geofence check
            // Note: WiFi-based location is approximate, so we use the assigned location's coordinates
            // The WiFi SSID is stored for reference and future location mapping
            await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/geofence-alert`, {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
                'Content-Type': 'application/json'
              },
              body: JSON.stringify({
                device_id: device.hostname,
                latitude: location.latitude,
                longitude: location.longitude
              })
            })
          }
        }
      } else {
        // WiFi data received but no SSID - still update last_seen
        await supabaseClient
          .from('devices')
          .update({ last_seen: currentTime })
          .eq('hostname', device.hostname)
      }
    }

    // Process geolocation data (fallback if GPS is available)
    if (payload.geolocation && payload.geolocation.length > 0) {
      hasData = true
      const geo = payload.geolocation[0]
      if (geo.latitude && geo.longitude) {
        // Update device location
        await supabaseClient
          .from('devices')
          .update({
            latitude: geo.latitude,
            longitude: geo.longitude,
            last_seen: currentTime
          })
          .eq('hostname', device.hostname)

        // Trigger geofence check if device has location
        if (device.location_id) {
          await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/geofence-alert`, {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              device_id: device.hostname,
              latitude: geo.latitude,
              longitude: geo.longitude
            })
          })
        }
      } else {
        // GPS data received but no coordinates - still update last_seen
        await supabaseClient
          .from('devices')
          .update({ last_seen: currentTime })
          .eq('hostname', device.hostname)
      }
    }

    // Process installed programs
    if (payload.installed_programs && Array.isArray(payload.installed_programs)) {
      hasData = true
      // Get active software blocklist
      const { data: blocklist } = await supabaseClient
        .from('software_blocklist')
        .select('name_pattern, path_pattern')
        .eq('is_active', true)

      let hasBlockedSoftware = false

      for (const program of payload.installed_programs) {
        // Check if software is blocked
        const isBlocked = blocklist?.some(block => {
          const nameMatch = program.name && 
            (block.name_pattern.includes('*') 
              ? program.name.toLowerCase().includes(block.name_pattern.toLowerCase().replace(/\*/g, ''))
              : program.name.toLowerCase() === block.name_pattern.toLowerCase())
          
          const pathMatch = !block.path_pattern || (program.install_location &&
            (block.path_pattern.includes('*')
              ? program.install_location.toLowerCase().includes(block.path_pattern.toLowerCase().replace(/\*/g, ''))
              : program.install_location.toLowerCase() === block.path_pattern.toLowerCase()))
          
          return nameMatch && pathMatch
        })

        if (isBlocked) {
          hasBlockedSoftware = true
        }

        await supabaseClient
          .from('software_inventory')
          .upsert({
            device_id: device.hostname,
            name: program.name,
            version: program.version,
            path: program.install_location,
            installed_at: program.install_date
          }, {
            onConflict: 'device_id,name'
          })
      }

      // Update device compliance status if blocked software detected
      if (hasBlockedSoftware) {
        await supabaseClient
          .from('devices')
          .update({ 
            compliance_status: 'non_compliant',
            last_seen: currentTime
          })
          .eq('hostname', device.hostname)
      } else {
        // Update last_seen even if no blocked software
        await supabaseClient
          .from('devices')
          .update({ last_seen: currentTime })
          .eq('hostname', device.hostname)
      }
    }

    // Process device health data
    if (payload.device_health || payload.battery_health || payload.system_uptime || payload.crash_events) {
      hasData = true
      
      console.log('Processing device health data:', {
        has_device_health: !!payload.device_health,
        has_battery_health: !!payload.battery_health,
        has_system_uptime: !!payload.system_uptime,
        has_crash_events: !!payload.crash_events
      })
      
      let batteryPercent: number | null = null
      let storageUsedPercent: number | null = null
      let bootTimeSeconds: number | null = null
      let crashCount: number = 0

      // Process battery health
      if (payload.battery_health && Array.isArray(payload.battery_health) && payload.battery_health.length > 0) {
        const battery = payload.battery_health[0]
        // Try to get percentage from various possible fields
        if (battery.percentage !== null && battery.percentage !== undefined && battery.percentage !== '') {
          batteryPercent = parseInt(battery.percentage) || null
        } else if (battery.percent_remaining !== null && battery.percent_remaining !== undefined && battery.percent_remaining !== '') {
          // Fallback to percent_remaining if percentage alias wasn't used
          batteryPercent = parseInt(battery.percent_remaining) || null
        }
        console.log('Battery data processed:', { 
          has_battery: true, 
          percentage: battery.percentage, 
          percent_remaining: battery.percent_remaining,
          final_batteryPercent: batteryPercent 
        })
      } else {
        console.log('No battery_health data in payload')
      }

      // Process storage usage
      if (payload.device_health && Array.isArray(payload.device_health) && payload.device_health.length > 0) {
        const health = payload.device_health[0]
        if (health.total_storage && health.used_storage) {
          const total = parseFloat(health.total_storage) || 0
          const used = parseFloat(health.used_storage) || 0
          if (total > 0) {
            storageUsedPercent = Math.round((used / total) * 100)
          }
        }
      }

      // Process system uptime (for boot time calculation)
      if (payload.system_uptime && Array.isArray(payload.system_uptime) && payload.system_uptime.length > 0) {
        const uptime = payload.system_uptime[0]
        if (uptime.uptime !== null && uptime.uptime !== undefined) {
          // Uptime is in seconds, we can use it as boot time estimate
          bootTimeSeconds = parseInt(uptime.uptime) || null
        }
      }

      // Process crash events
      if (payload.crash_events && Array.isArray(payload.crash_events) && payload.crash_events.length > 0) {
        const crash = payload.crash_events[0]
        if (crash.crash_count !== null && crash.crash_count !== undefined) {
          crashCount = parseInt(crash.crash_count) || 0
        }
      }

      // Upsert health data (performance_status will be calculated by trigger)
      // Use service_role client which bypasses RLS
      const upsertData = {
        device_hostname: device.hostname,
        battery_health_percent: batteryPercent,
        storage_used_percent: storageUsedPercent,
        boot_time_avg_seconds: bootTimeSeconds,
        crash_error_count: crashCount
      }
      
      console.log('Attempting to upsert device_health:', upsertData)
      
      const { data: healthData, error: healthError } = await supabaseClient
        .from('device_health')
        .upsert(upsertData, {
          onConflict: 'device_hostname'
        })
        .select()
      
      if (healthError) {
        console.error('Error upserting device_health:', JSON.stringify(healthError, null, 2))
        console.error('Error details:', {
          message: healthError.message,
          details: healthError.details,
          hint: healthError.hint,
          code: healthError.code
        })
      } else {
        console.log('Device health upserted successfully:', {
          device_hostname: device.hostname,
          battery_health_percent: batteryPercent,
          storage_used_percent: storageUsedPercent,
          boot_time_avg_seconds: bootTimeSeconds,
          crash_error_count: crashCount,
          returned_data: healthData,
          returned_count: healthData?.length || 0
        })
        
        // Verify the data was actually stored by querying it back
        if (!healthData || healthData.length === 0) {
          console.warn('WARNING: Upsert returned no data. Verifying with separate query...')
          const { data: verifyData, error: verifyError } = await supabaseClient
            .from('device_health')
            .select('*')
            .eq('device_hostname', device.hostname)
            .single()
          
          if (verifyError) {
            console.error('Verification query failed:', verifyError)
          } else if (verifyData) {
            console.log('Verification successful - data exists:', verifyData)
          } else {
            console.error('CRITICAL: Data was not stored despite successful upsert!')
          }
        }
      }
    }

    // Process browser history
    if (payload.browser_history && Array.isArray(payload.browser_history)) {
      hasData = true
      for (const history of payload.browser_history) {
        if (history.url) {
          const url = new URL(history.url)
          await supabaseClient
            .from('web_activity')
            .insert({
              device_id: device.hostname,
              url: history.url,
              domain: url.hostname,
              category: categorizeDomain(url.hostname),
              timestamp: new Date(parseInt(history.last_visit_time) * 1000).toISOString()
            })
        }
      }
      // Update last_seen when browser history is received
      await supabaseClient
        .from('devices')
        .update({ last_seen: currentTime })
        .eq('hostname', device.hostname)
    }

    // Process system info (heartbeat - updates last_seen even if no other data)
    if (payload.system_info && Array.isArray(payload.system_info) && payload.system_info.length > 0) {
      hasData = true
      await supabaseClient
        .from('devices')
        .update({ last_seen: currentTime })
        .eq('hostname', device.hostname)
    }

    // If ANY data was received, ensure last_seen is updated (final safety check)
    if (hasData) {
      await supabaseClient
        .from('devices')
        .update({ last_seen: currentTime })
        .eq('hostname', device.hostname)
    }

    return new Response(
      JSON.stringify({ success: true, device_hostname: device.hostname, last_seen: currentTime }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Simple domain categorization
function categorizeDomain(domain: string): string {
  const socialMedia = ['facebook.com', 'instagram.com', 'twitter.com', 'linkedin.com', 'tiktok.com']
  const gaming = ['steam.com', 'epicgames.com', 'roblox.com']
  
  if (socialMedia.some(sm => domain.includes(sm))) return 'social_media'
  if (gaming.some(g => domain.includes(g))) return 'gaming'
  return 'other'
}
