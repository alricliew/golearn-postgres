
DROP FUNCTION IF EXISTS create_sitemap_entries CASCADE; 
DROP FUNCTION IF EXISTS get_sitemap_entries CASCADE; 
DROP FUNCTION IF EXISTS get_sitemap CASCADE; 
DROP FUNCTION IF EXISTS get_sitemap_count_by_type CASCADE; 
CREATE OR REPLACE FUNCTION create_sitemap_entries(sitemap_entries JSONB)
RETURNS SETOF sitemap_entries AS $$
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
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_sitemap_entries(
  p_type VARCHAR(50) DEFAULT NULL,
  p_per_page INT DEFAULT 45000,
  p_page INT DEFAULT 1,
  p_order_by TEXT DEFAULT 'lastmod.DESC'
)
RETURNS SETOF sitemap_entries AS $$
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
    -- RAISE EXCEPTION '% ORDER BY % LIMIT % OFFSET %',v_where_query, v_order_clause,  p_per_page, (p_page - 1) * p_per_page;

    RETURN QUERY EXECUTE format('
    SELECT 
        n_i.id as id, 
        n_i.type as type,
        n_i.url as url,
        n_i.lastmod as lastmod,
        n_i.changefreq as changefreqxx,
        n_i.priority as priority,
        n_i.date_edit as date_edit,
        n_i.date_add as date_add
    FROM sitemap_entries n_i
    %s
    ORDER BY %s
    LIMIT %L OFFSET %L
    ',
    v_where_query, v_order_clause, p_per_page, (p_page - 1) * p_per_page);

END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS get_sitemap CASCADE; 
create or replace function get_sitemap(
  p_type text,
  p_page_no int default 0,
  p_limit int default 45000
)
returns table (
  id bigint,
  type varchar(50),
  url text,
  lastmod timestamptz,
  changefreq varchar(50),
  priority int,
  date_edit timestamptz
)
language sql
as $$
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


DROP FUNCTION IF EXISTS get_sitemap_count_by_type CASCADE;
CREATE OR REPLACE FUNCTION get_sitemap_count_by_type(
  p_type VARCHAR[] DEFAULT ARRAY['PAGE', 'AREA', 'SUBJECT', 'CENTER', 'OTHER']
)
RETURNS TABLE (
  type text,
  count bigint
)
LANGUAGE sql
AS $$
  SELECT type, COUNT(*)::bigint
  FROM sitemap_entries
  WHERE type = ANY(p_type)
  GROUP BY type
  ORDER BY type;
$$;
