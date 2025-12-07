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
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const payload = await req.json()

    // Extract device info from osquery payload
    const hostname = payload.hostname || payload.host?.hostname
    const fleetUuid = payload.uuid || payload.host?.uuid

    if (!hostname && !fleetUuid) {
      return new Response(
        JSON.stringify({ error: 'Missing device identifier' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Find device by fleet_uuid or hostname
    const { data: device } = await supabaseClient
      .from('devices')
      .select('id, location_id')
      .or(`fleet_uuid.eq.${fleetUuid},hostname.eq.${hostname}`)
      .single()

    if (!device) {
      return new Response(
        JSON.stringify({ error: 'Device not found. Please enroll device first.' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Process geolocation data
    if (payload.geolocation && payload.geolocation.length > 0) {
      const geo = payload.geolocation[0]
      if (geo.latitude && geo.longitude) {
        // Update device location
        await supabaseClient
          .from('devices')
          .update({
            latitude: geo.latitude,
            longitude: geo.longitude,
            last_seen: new Date().toISOString()
          })
          .eq('id', device.id)

        // Trigger geofence check if device has location
        if (device.location_id) {
          await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/geofence-alert`, {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              device_id: device.id,
              latitude: geo.latitude,
              longitude: geo.longitude
            })
          })
        }
      }
    }

    // Process installed programs
    if (payload.installed_programs && Array.isArray(payload.installed_programs)) {
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
            device_id: device.id,
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
          .update({ compliance_status: 'non_compliant' })
          .eq('id', device.id)
      }
    }

    // Process browser history
    if (payload.browser_history && Array.isArray(payload.browser_history)) {
      for (const history of payload.browser_history) {
        if (history.url) {
          const url = new URL(history.url)
          await supabaseClient
            .from('web_activity')
            .insert({
              device_id: device.id,
              url: history.url,
              domain: url.hostname,
              category: categorizeDomain(url.hostname),
              timestamp: new Date(parseInt(history.last_visit_time) * 1000).toISOString()
            })
        }
      }
    }

    return new Response(
      JSON.stringify({ success: true, device_id: device.id }),
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

