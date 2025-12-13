// Edge Function: Location-aware geofence check
// Checks device GPS against assigned location's bounds

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Calculate distance between two GPS points (Haversine formula)
function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000 // Earth radius in meters
  const dLat = (lat2 - lat1) * Math.PI / 180
  const dLon = (lon2 - lon1) * Math.PI / 180
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { device_id, latitude, longitude, wifi_ssid_match } = await req.json()

    if (!device_id || latitude === undefined || longitude === undefined) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: device_id, latitude, longitude' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get device with location (device_id is now hostname after migration 008)
    const { data: device, error: deviceError } = await supabaseClient
      .from('devices')
      .select('hostname, location_id, latitude, longitude')
      .eq('hostname', device_id)
      .single()

    if (deviceError || !device) {
      return new Response(
        JSON.stringify({ error: 'Device not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!device.location_id) {
      return new Response(
        JSON.stringify({ error: 'Device has no assigned location' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get location details
    const { data: location, error: locationError } = await supabaseClient
      .from('locations')
      .select('id, name, latitude, longitude, radius_meters')
      .eq('id', device.location_id)
      .single()

    if (locationError || !location) {
      return new Response(
        JSON.stringify({ error: 'Location not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Use default radius if not set (shouldn't happen, but safety check)
    const radius = location.radius_meters || 1000

    // Calculate distance from device to location center (in meters)
    const distance = calculateDistance(
      parseFloat(latitude.toString()),
      parseFloat(longitude.toString()),
      parseFloat(location.latitude.toString()),
      parseFloat(location.longitude.toString())
    )

    // Check if device is outside geofence
    // For WiFi-based geofencing: if wifi_ssid_match is false, device is outside
    // For GPS-based geofencing: if distance > radius_meters, device is outside
    let isOutside: boolean
    if (wifi_ssid_match !== undefined) {
      // WiFi-based geofencing: check if WiFi SSID matched the location
      isOutside = !wifi_ssid_match
    } else {
      // GPS-based geofencing: check distance
      isOutside = distance > radius
    }

    // Update device location
    await supabaseClient
      .from('devices')
      .update({
        latitude: latitude,
        longitude: longitude,
        last_seen: new Date().toISOString()
      })
      .eq('hostname', device_id)

    if (isOutside) {
      // Check if there's already an unresolved alert
      const { data: existingAlert } = await supabaseClient
        .from('geofence_alerts')
        .select('id')
        .eq('device_id', device_id)
        .eq('location_id', location.id)
        .is('resolved_at', null)
        .single()

      if (!existingAlert) {
        // Create new alert
        const { error: alertError } = await supabaseClient
          .from('geofence_alerts')
          .insert({
            device_id: device_id, // hostname
            location_id: location.id,
            violation_type: wifi_ssid_match === false ? 'wifi_mismatch' : 'outside_bounds',
            latitude: latitude,
            longitude: longitude,
            distance_meters: wifi_ssid_match === false ? null : Math.round(distance)
          })

        if (alertError) {
          console.error('Error creating alert:', alertError)
        }

        // Update device compliance status
        await supabaseClient
          .from('devices')
          .update({ compliance_status: 'non_compliant' })
          .eq('hostname', device_id)
      }

      const violationMessage = wifi_ssid_match === false
        ? `Device WiFi SSID does not match ${location.name} location (WiFi-based geofence violation)`
        : `Device is ${Math.round(distance)}m outside ${location.name} geofence (radius: ${radius}m)`

      return new Response(
        JSON.stringify({
          status: 'violation',
          message: violationMessage,
          distance_meters: wifi_ssid_match === false ? null : Math.round(distance),
          radius_meters: radius,
          location_name: location.name,
          wifi_based: wifi_ssid_match !== undefined
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } else {
      // Device is inside geofence - resolve any existing alerts
      await supabaseClient
        .from('geofence_alerts')
        .update({ resolved_at: new Date().toISOString() })
        .eq('device_id', device_id)
        .eq('location_id', location.id)
        .is('resolved_at', null)

      // Update device compliance status
      await supabaseClient
        .from('devices')
        .update({ compliance_status: 'compliant' })
        .eq('hostname', device_id)

      return new Response(
        JSON.stringify({
          status: 'compliant',
          message: `Device is within ${location.name} geofence (${Math.round(distance)}m from center, radius: ${radius}m)`,
          distance_meters: Math.round(distance),
          radius_meters: radius,
          location_name: location.name
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
