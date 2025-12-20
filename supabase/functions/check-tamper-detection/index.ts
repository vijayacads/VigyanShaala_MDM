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
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Check for offline devices
    const { data: offlineDevices, error } = await supabaseClient
      .rpc('detect_offline_devices')

    if (error) throw error

    // Create tamper events for offline devices
    const tamperEvents = (offlineDevices || []).map((device: any) => ({
      device_hostname: device.device_hostname,
      event_type: 'offline',
      severity: device.severity,
      last_seen_before: device.last_seen,
      details: {
        minutes_offline: device.minutes_offline,
        detected_at: new Date().toISOString()
      }
    }))

    if (tamperEvents.length > 0) {
      const { error: insertError } = await supabaseClient
        .from('tamper_events')
        .insert(tamperEvents)

      if (insertError) throw insertError

      console.log(`Alert: ${tamperEvents.length} devices possibly bypassed MDM`)
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        devices_checked: offlineDevices?.length || 0,
        tamper_events_created: tamperEvents.length
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
