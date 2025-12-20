// Edge Function: Generate Chrome policy JSON from website blocklist
// Returns policy that can be deployed to devices via registry or Group Policy

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

    // Get active website blocklist
    const { data: blocklist, error } = await supabaseClient
      .from('website_blocklist')
      .select('domain_pattern')
      .eq('is_active', true)

    if (error) throw error

    const domains = (blocklist || []).map(item => item.domain_pattern)

    // Generate Chrome policy JSON
    const chromePolicy = {
      URLBlocklist: domains,
      URLWhitelist: [] // Can be customized
    }

    // Also generate registry format for Windows
    const registryFormat = domains.map(domain => ({
      name: domain,
      value: domain
    }))

    return new Response(
      JSON.stringify({
        chrome_policy: chromePolicy,
        registry_format: registryFormat,
        domains: domains,
        count: domains.length,
        instructions: {
          windows_registry: "Deploy to: HKLM\\SOFTWARE\\Policies\\Google\\Chrome\\URLBlocklist",
          group_policy: "Computer Configuration → Policies → Administrative Templates → Google → Google Chrome → Block access to a list of URLs",
          json_file: "Save chrome_policy as JSON and deploy via MDM or Group Policy"
        }
      }, null, 2),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})




