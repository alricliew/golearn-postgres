DROP FUNCTION IF EXISTS create_sitemap_entries CASCADE; 
DROP FUNCTION IF EXISTS get_sitemap_entries CASCADE; 
DROP FUNCTION IF EXISTS get_sitemap CASCADE; 
DROP FUNCTION IF EXISTS get_sitemap_count_by_type CASCADE; 
DROP FUNCTION IF EXISTS get_sitemap_by_row CASCADE; 
DROP FUNCTION IF EXISTS import_sitemap_csv CASCADE;
SELECT pg_stat_clear_snapshot();

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

CREATE OR REPLACE FUNCTION get_sitemap(
  p_type TEXT,
  p_page_no INT default 0,
  p_limit INT default 1000
)
RETURNS TABLE (
  id bigint,
  type varchar(50),
  url TEXT,
  lastmod timestamptz,
  changefreq varchar(50),
  priority INT,
  date_edit timestamptz
)
language sql
as $$
  SELECT 
    id,
    type,
    url,
    lastmod,
    changefreq,
    priority,
    date_edit
  FROM sitemap_entries
  WHERE type = p_type 
  ORDER BY id
  LIMIT p_limit
  OFFSET p_page_no * p_limit;
$$;


-- Get sitemap ocount by type
CREATE OR REPLACE FUNCTION get_sitemap_count_by_type(
  p_type VARCHAR[] DEFAULT ARRAY['PAGE', 'AREA', 'SUBJECT', 'CENTER', 'TUITION', 'OTHER']
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

-- Use materialized view to get sitemap
CREATE OR REPLACE FUNCTION get_sitemap_by_row(
  p_type TEXT,
  p_start BIGINT,
  p_end BIGINT
)
RETURNS TABLE (
  id BIGINT,
  type VARCHAR(50),
  url TEXT,
  lastmod TIMESTAMPTZ,
  changefreq VARCHAR(20),
  priority NUMERIC(2,1),
  date_add TIMESTAMPTZ,
  date_edit TIMESTAMPTZ
)
LANGUAGE SQL
AS $$
  SELECT id, type, url, lastmod, changefreq, priority, date_add, date_edit
  FROM sitemap_row_numbers
  WHERE type = p_type
    AND rn > p_start
    AND rn <= p_end
  ORDER BY id
  LIMIT 1000; -- max rows per RPC call
$$;

-- Bulk upload of sitemap using CSV (parsed client-side) with insert/upsert/overwrite
CREATE OR REPLACE FUNCTION import_sitemap_csv(
    rows JSONB,
    p_action TEXT DEFAULT 'insert'  -- insert | upsert | overwrite
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    affected_count INTEGER := 0;
BEGIN

    IF p_action NOT IN ('insert','upsert','overwrite') THEN
        RAISE EXCEPTION 'Invalid action. Use insert | upsert | overwrite';
    END IF;

    -- ============================================================
    -- INSERT / UPSERT
    -- ============================================================
    IF p_action IN ('insert','upsert') THEN

        INSERT INTO sitemap_entries (
            type,
            url,
            lastmod,
            changefreq,
            priority,
            date_edit,
            date_add
        )
        SELECT
            COALESCE(row->>'type','PAGE'),
            row->>'url',
            CASE 
                WHEN row->>'lastmod' IS NOT NULL AND row->>'lastmod' <> ''
                THEN (row->>'lastmod')::timestamptz
                ELSE NOW()
            END,
            NULLIF(row->>'changefreq',''),
            CASE 
                WHEN row->>'priority' IS NOT NULL AND row->>'priority' <> ''
                THEN (row->>'priority')::NUMERIC
                ELSE NULL
            END,
            CASE 
                WHEN row->>'date_edit' IS NOT NULL AND row->>'date_edit' <> ''
                THEN (row->>'date_edit')::timestamptz
                ELSE NULL
            END,
            CASE 
                WHEN row->>'date_add' IS NOT NULL AND row->>'date_add' <> ''
                THEN (row->>'date_add')::timestamptz
                ELSE NOW()
            END
        FROM jsonb_array_elements(rows) row
        ON CONFLICT (url)
        DO UPDATE
        SET
            type       = EXCLUDED.type,
            lastmod    = EXCLUDED.lastmod,
            changefreq = EXCLUDED.changefreq,
            priority   = EXCLUDED.priority,
            date_edit  = EXCLUDED.date_edit,
            date_add   = EXCLUDED.date_add
        WHERE p_action = 'upsert';

    -- ============================================================
    -- OVERWRITE (delete then insert fresh)
    -- ============================================================
    ELSE
        -- Delete existing entries for the URLs in the JSON
        DELETE FROM sitemap_entries se
        USING jsonb_array_elements(rows) row
        WHERE se.url = row->>'url';

        -- Insert fresh
        INSERT INTO sitemap_entries (
            type,
            url,
            lastmod,
            changefreq,
            priority,
            date_edit,
            date_add
        )
        SELECT
            COALESCE(row->>'type','PAGE'),
            row->>'url',
            CASE 
                WHEN row->>'lastmod' IS NOT NULL AND row->>'lastmod' <> ''
                THEN (row->>'lastmod')::timestamptz
                ELSE NOW()
            END,
            NULLIF(row->>'changefreq',''),
            CASE 
                WHEN row->>'priority' IS NOT NULL AND row->>'priority' <> ''
                THEN (row->>'priority')::NUMERIC
                ELSE NULL
            END,
            CASE 
                WHEN row->>'date_edit' IS NOT NULL AND row->>'date_edit' <> ''
                THEN (row->>'date_edit')::timestamptz
                ELSE NULL
            END,
            CASE 
                WHEN row->>'date_add' IS NOT NULL AND row->>'date_add' <> ''
                THEN (row->>'date_add')::timestamptz
                ELSE NOW()
            END
        FROM jsonb_array_elements(rows) row;

    END IF;

    GET DIAGNOSTICS affected_count = ROW_COUNT;
    RETURN affected_count;

END;
$$;

-- -- Bulk upload of sitemap using CSV (parsed client-side)
-- -- Flow: CSV → JSON → staging → main table
-- CREATE OR REPLACE FUNCTION import_sitemap_csv(rows JSONB)
-- RETURNS INTEGER
-- LANGUAGE plpgsql
-- SECURITY DEFINER
-- AS $$
-- DECLARE
--     inserted_count INTEGER;
-- BEGIN
--     -- Insert into main table
--     INSERT INTO sitemap_entries (type, url, lastmod, changefreq, priority, date_edit, date_add)
--     SELECT
--         COALESCE(row->>'type', 'PAGE'),
--         row->>'url',
--         CASE 
--             WHEN row->>'lastmod' IS NOT NULL AND row->>'lastmod' <> ''
--             THEN (row->>'lastmod')::timestamptz
--             ELSE NOW()
--         END,
--         NULLIF(row->>'changefreq', ''),
--         CASE WHEN row->>'priority' IS NOT NULL AND row->>'priority' <> ''
--              THEN (row->>'priority')::NUMERIC
--              ELSE NULL
--         END,
--         CASE WHEN row->>'date_edit' IS NOT NULL AND row->>'date_edit' <> ''
--              THEN (row->>'date_edit')::timestamptz
--              ELSE NULL
--         END,
--         CASE WHEN row->>'date_add' IS NOT NULL AND row->>'date_add' <> ''
--              THEN (row->>'date_add')::timestamptz
--              ELSE NOW()
--         END
--     FROM jsonb_array_elements(rows) AS row
--     ON CONFLICT (url) DO NOTHING;

--     GET DIAGNOSTICS inserted_count = ROW_COUNT;

--     -- Refresh the materialized view for row-number pagination
--     -- Only do this if the materialized view exists
--     -- BEGIN
--     --     REFRESH MATERIALIZED VIEW sitemap_row_numbers;
--     -- EXCEPTION WHEN undefined_table THEN
--     --     -- Materialized view doesn't exist yet; skip refresh
--     --     RAISE NOTICE 'Materialized view sitemap_row_numbers does not exist, skipping refresh.';
--     -- END;

--     RETURN inserted_count;
-- END;
-- $$;

-- -- (TODO: Keset pagination)
-- -- Use materialized view to get sitemap
-- CREATE OR REPLACE FUNCTION get_sitemap_by_row(
--   p_type TEXT,
--   p_page_no BIGINT DEFAULT 0
-- )
-- RETURNS TABLE (
--   id BIGINT,
--   type VARCHAR(50),
--   url TEXT,
--   lastmod TIMESTAMPTZ,
--   changefreq VARCHAR(20),
--   priority NUMERIC(2,1),
--   date_add TIMESTAMPTZ,
--   date_edit TIMESTAMPTZ
-- )
-- LANGUAGE SQL
-- AS $$
--   SELECT *
--   FROM sitemap_entries
--   WHERE type=p_type
--     AND id >= (SELECT start_id FROM sitemap_page_cursors
--               WHERE type=p_type AND page_number=p_page_no)
--   ORDER BY id
--   LIMIT 1000; -- max rows per RPC call
-- $$;