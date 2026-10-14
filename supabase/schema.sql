


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";





SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."sitemap_entries" (
    "id" integer NOT NULL,
    "type" character varying(50) DEFAULT 'PAGE'::character varying NOT NULL,
    "url" "text" NOT NULL,
    "lastmod" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "changefreq" character varying(20),
    "priority" numeric(2,1),
    "date_edit" "date"
);


ALTER TABLE "public"."sitemap_entries" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_sitemap_entries"("sitemap_entries" "jsonb") RETURNS SETOF "public"."sitemap_entries"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  INSERT INTO sitemap_entries (url, lastmod, type, priority, changefreq)
  SELECT
    entry->>'url',
    CASE
      WHEN jsonb_typeof(entry->'lastmod') = 'string'
           AND (entry->>'lastmod') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
        THEN (entry->>'lastmod')::timestamptz   -- only cast valid ISO-ish timestamps
      ELSE NOW()                                -- fallback safely
    END AS lastmod,
    COALESCE((entry->>'type'), 'PAGE'),
    COALESCE((entry->>'priority')::NUMERIC, 0.5),
    COALESCE(entry->>'changefreq', '')
  FROM jsonb_array_elements(sitemap_entries) AS entry
  ON CONFLICT (url) DO UPDATE
  SET
    type = EXCLUDED.type,
    priority = EXCLUDED.priority,
    changefreq = EXCLUDED.changefreq,
    lastmod = NOW()
  WHERE
    EXCLUDED.lastmod > sitemap_entries.lastmod   -- only update if newer
  RETURNING *;
END;
$$;


ALTER FUNCTION "public"."create_sitemap_entries"("sitemap_entries" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_sitemap"("p_type" "text", "p_page_no" integer DEFAULT 0, "p_limit" integer DEFAULT 45000) RETURNS TABLE("id" bigint, "type" character varying, "url" "text", "lastmod" timestamp with time zone, "changefreq" character varying, "priority" integer, "date_edit" timestamp with time zone)
    LANGUAGE "sql"
    AS $$
  select 
    id,
    type,
    url,
    lastmod,
    changefreq,
    priority,
    date_edit
  from sitemap_entries
  where type = p_type
  order by id
  limit p_limit
  offset p_page_no * p_limit;
$$;


ALTER FUNCTION "public"."get_sitemap"("p_type" "text", "p_page_no" integer, "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_sitemap_count_by_type"("p_type" character varying[] DEFAULT ARRAY['PAGE'::"text", 'AREA'::"text", 'SUBJECT'::"text", 'CENTER'::"text", 'OTHER'::"text"]) RETURNS TABLE("type" "text", "count" bigint)
    LANGUAGE "sql"
    AS $$
  SELECT type, COUNT(*)::bigint
  FROM sitemap_entries
  WHERE type = ANY(p_type)
  GROUP BY type
  ORDER BY type;
$$;


ALTER FUNCTION "public"."get_sitemap_count_by_type"("p_type" character varying[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_sitemap_entries"("p_type" character varying DEFAULT NULL::character varying, "p_per_page" integer DEFAULT 45000, "p_page" integer DEFAULT 1, "p_order_by" "text" DEFAULT 'lastmod.DESC'::"text") RETURNS SETOF "public"."sitemap_entries"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_order_part TEXT;
    v_order_parts TEXT[];
    v_order_clause TEXT := '';
    v_where_query TEXT := '';
    v_where_metadata TEXT := '';
BEGIN
      -- Split the p_order_by string into parts based on commas
    v_order_parts := string_to_array(p_order_by, ',');

    -- Loop through each part and build the corresponding ORDER BY clause
    FOR i IN 1..array_length(v_order_parts, 1) LOOP
        v_order_part := v_order_parts[i];

        -- Handle order by column and direction
        IF v_order_part LIKE 'lastmod%' THEN
            -- For lastmod ordering
            v_order_clause := v_order_clause || 'n_i.lastmod ' || split_part(v_order_part, '.', 2) || ', ';
            
        END IF;
    END LOOP;

    -- Removing the trailing comma and space
    IF length(v_order_clause) > 2 THEN
        v_order_clause := left(v_order_clause, length(v_order_clause) - 2);
    END IF;

    --  WHERE conditions
    v_where_query := 'WHERE TRUE' || 
        ' AND n_i.type = ' || quote_literal(p_type);
    RAISE EXCEPTION '% ORDER BY % LIMIT % OFFSET %',v_where_query, v_order_clause,  p_per_page, (p_page - 1) * p_per_page;

    RETURN QUERY EXECUTE format('
    SELECT 
        n_i.id as id, 
        n_i.type as type,
        n_i.url as url,
        n_i.lastmod as lastmod,
        n_i.changefreq as changefreq,
        n_i.priority as priority
    FROM sitemap_entries n_i
    %s
    ORDER BY %s
    LIMIT %L OFFSET %L
    ',
    v_where_query, v_order_clause, p_per_page, (p_page - 1) * p_per_page);

END;
$$;


ALTER FUNCTION "public"."get_sitemap_entries"("p_type" character varying, "p_per_page" integer, "p_page" integer, "p_order_by" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cities" (
    "id" integer NOT NULL,
    "name" "text" NOT NULL
);


ALTER TABLE "public"."cities" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."cities_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."cities_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."cities_id_seq" OWNED BY "public"."cities"."id";



CREATE SEQUENCE IF NOT EXISTS "public"."sitemap_entries_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."sitemap_entries_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."sitemap_entries_id_seq" OWNED BY "public"."sitemap_entries"."id";



ALTER TABLE ONLY "public"."cities" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."cities_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."sitemap_entries" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."sitemap_entries_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."cities"
    ADD CONSTRAINT "cities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sitemap_entries"
    ADD CONSTRAINT "sitemap_entries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sitemap_entries"
    ADD CONSTRAINT "sitemap_entries_url_key" UNIQUE ("url");



CREATE POLICY "Enable read access for all sitemap_entries" ON "public"."sitemap_entries" USING (true);



ALTER TABLE "public"."cities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sitemap_entries" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON TABLE "public"."sitemap_entries" TO "anon";
GRANT ALL ON TABLE "public"."sitemap_entries" TO "authenticated";
GRANT ALL ON TABLE "public"."sitemap_entries" TO "service_role";



GRANT ALL ON FUNCTION "public"."create_sitemap_entries"("sitemap_entries" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."create_sitemap_entries"("sitemap_entries" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_sitemap_entries"("sitemap_entries" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_sitemap"("p_type" "text", "p_page_no" integer, "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_sitemap"("p_type" "text", "p_page_no" integer, "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_sitemap"("p_type" "text", "p_page_no" integer, "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_sitemap_count_by_type"("p_type" character varying[]) TO "anon";
GRANT ALL ON FUNCTION "public"."get_sitemap_count_by_type"("p_type" character varying[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_sitemap_count_by_type"("p_type" character varying[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_sitemap_entries"("p_type" character varying, "p_per_page" integer, "p_page" integer, "p_order_by" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_sitemap_entries"("p_type" character varying, "p_per_page" integer, "p_page" integer, "p_order_by" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_sitemap_entries"("p_type" character varying, "p_per_page" integer, "p_page" integer, "p_order_by" "text") TO "service_role";


















GRANT ALL ON TABLE "public"."cities" TO "anon";
GRANT ALL ON TABLE "public"."cities" TO "authenticated";
GRANT ALL ON TABLE "public"."cities" TO "service_role";



GRANT ALL ON SEQUENCE "public"."cities_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."cities_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."cities_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."sitemap_entries_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."sitemap_entries_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."sitemap_entries_id_seq" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































