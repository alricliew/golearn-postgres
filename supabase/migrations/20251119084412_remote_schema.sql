drop extension if exists "pg_net";

create sequence "public"."cities_id_seq";


  create table "public"."cities" (
    "id" integer not null default nextval('public.cities_id_seq'::regclass),
    "name" text not null
      );


alter table "public"."cities" enable row level security;

alter table "public"."sitemap_entries" drop column "date_add";

alter table "public"."sitemap_entries" alter column "date_edit" set data type date using "date_edit"::date;

alter sequence "public"."cities_id_seq" owned by "public"."cities"."id";

CREATE UNIQUE INDEX cities_pkey ON public.cities USING btree (id);

alter table "public"."cities" add constraint "cities_pkey" PRIMARY KEY using index "cities_pkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.get_sitemap_entries(p_type character varying DEFAULT NULL::character varying, p_per_page integer DEFAULT 45000, p_page integer DEFAULT 1, p_order_by text DEFAULT 'lastmod.DESC'::text)
 RETURNS SETOF public.sitemap_entries
 LANGUAGE plpgsql
AS $function$
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
$function$
;

grant delete on table "public"."cities" to "anon";

grant insert on table "public"."cities" to "anon";

grant references on table "public"."cities" to "anon";

grant select on table "public"."cities" to "anon";

grant trigger on table "public"."cities" to "anon";

grant truncate on table "public"."cities" to "anon";

grant update on table "public"."cities" to "anon";

grant delete on table "public"."cities" to "authenticated";

grant insert on table "public"."cities" to "authenticated";

grant references on table "public"."cities" to "authenticated";

grant select on table "public"."cities" to "authenticated";

grant trigger on table "public"."cities" to "authenticated";

grant truncate on table "public"."cities" to "authenticated";

grant update on table "public"."cities" to "authenticated";

grant delete on table "public"."cities" to "service_role";

grant insert on table "public"."cities" to "service_role";

grant references on table "public"."cities" to "service_role";

grant select on table "public"."cities" to "service_role";

grant trigger on table "public"."cities" to "service_role";

grant truncate on table "public"."cities" to "service_role";

grant update on table "public"."cities" to "service_role";


