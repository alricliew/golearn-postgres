// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { ZodError } from "https://esm.sh/zod@3.22.1";

declare const Deno: any

// import { createClient } from '@supabase/supabase-js'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
const supabaseUrl = Deno.env.get('SUPABASE_URL')
const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
const supabase = createClient(supabaseUrl, supabaseAnonKey)

import { SitemapEntries } from "../types.ts"
// const myType = require( "../types" )

Deno.serve(async (req: Request) => {

  switch(req.method){
    // Get sitemap
    // query params: 
    // ?page=8&type=PAGE&order_by="date.desc"
    // page - (Each page consist of 45k urls )
    // type - sitemap by type
    // order_by - date.asc / date.desc
    case "GET": {
      try {
        const url = new URL(req.url);
        const params = {
          p_type: url.searchParams.get("type") ? url.searchParams.get("type") ?? null : null,
          p_per_page: parseInt(url.searchParams.get("per_page") || "450000"),
          p_page: parseInt(url.searchParams.get("page") || "1"),
          p_order_by: url.searchParams.get("order_by") ?? "lastmod.DESC",
        }

        console.log("GET sitemap_entries", params)
        const { data, error } = await supabase.rpc('get_sitemap_entries', params)
        console.log("GET sitemap_entries data", data)

        if (error) throw error; 
        return new Response(JSON.stringify(data), { status: 200 })
      } catch (error) {
        return new Response(JSON.stringify({ error }), { status: 400 })

      }

    }
    // Update sitemaps 
    // body: {
      // url: [
      //    {url: "/newpath", lastmod: <W3C time format> default - current date, type: Type of url: 'PAGE'(default), 'AREA_SUBJECT', 'SUBJECT', 'POST", "ADVERTISEMENT", changefreq: optional, priority: optional }  
      //    {url: "/path2", lastmod: null, type: "PAGE"}, 
      //    {url: "/path3", lastmod: "2023-10-27T10:30:00Z", type: "PAGE"}, 
      // ]
    // }
    // For existing path, lastmod cannot be in the past. 
    case "POST": {
      const sitemap_entries_test = 
      {
        "url": [
          {"url": "/", "lastmod": "2023-10-27T10:30:00Z"},
          {"url": "/about", "lastmod": ""},
          {"url": "/pricing", "lastmod": "undefined"},
          {"url": "/join-us", "lastmod": "error"},
          {"url": "/contact-us", "lastmod": "2024-01-23"}
        ]
      }
      try {
        const body = await req.json();
        console.log("POST body", body)

        const zodResult = SitemapEntries.safeParse( body ) // sitemap_entries_test
        if (!zodResult.success) {
          if (zodResult.error instanceof ZodError) {
            // Map each issue into "path: message"
            const messages = zodResult.error.issues.map((issue: any) => {
              const path = issue.path.length ? issue.path.join(".") : "root";
              return `${path}: ${issue.message}`;
            });
            // Join as single string
            throw { "message": messages.join(", ") }
          }
        }

        const sitemap_entries =  body?.url || []; //sitemap_entries_test
        const { data, error } = await supabase.rpc('create_sitemap_entries', {
          sitemap_entries
        })
        if (error) throw error; 
        return new Response(JSON.stringify(data), { status: 200 })
      } catch (error) {
        return new Response(JSON.stringify({ error }), { status: 400 })
      }
     

    }
    // Delete sitemap
    // DELETE /api/sitemap/[sitemapid]
    // DELETE /api/sitemap?url=%20newpath1,
    case "DELETE": {
      const { name } = await req.json()
      const data = {
        message: `Hello ${name}!`,
      }
      console.log("GET sitemap_entries", data)
      return new Response(
        JSON.stringify(data),
        { headers: { "Content-Type": "application/json" } },
      )
    }
    default: {
      const { name } = await req.json()
      const data = {
        message: `Hello ${name}!`,
      }
      console.log("GET sitemap_entries", data)
      return new Response(
        JSON.stringify(data),
        { headers: { "Content-Type": "application/json" } },
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
