// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

declare const Deno: any

// import { createClient } from '@supabase/supabase-js'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
const supabaseUrl = Deno.env.get('SUPABASE_URL')
const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
const supabase = createClient(supabaseUrl, supabaseAnonKey)

Deno.serve(async (req: Request) => {

  switch(req.method){
    case "GET": {
      try {
        const { data, error } = await supabase.rpc("get_sitemap_entries_count");
        if (error) throw error;
        console.log("Total URLs:", data);
        return new Response(JSON.stringify(data), { status: 200 })
      } catch (error) {
        return new Response(JSON.stringify({ error }), { status: 400 })
      }

    }
    default: {
      const data = {
        message: `Method unsupported ${req.method}!`,
      }
      console.log("GET sitemap_entries", data)
      return new Response(
        JSON.stringify(data),
        { status: 403 }
      )
    }
  }

})

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/hello' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

  Local project view
  http://localhost:54323/
*/
