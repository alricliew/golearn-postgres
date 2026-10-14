
DROP FUNCTION IF EXISTS get_product_groups;
DROP FUNCTION IF EXISTS upsert_product_groups CASCADE; 

SELECT pg_stat_clear_snapshot();

CREATE OR REPLACE FUNCTION get_product_groups(
    p_id UUID[] DEFAULT NULL,
    p_account_id UUID[] DEFAULT NULL,
    p_status VARCHAR[] DEFAULT NULL,
    p_search_text TEXT DEFAULT NULL,
    p_per_page INT DEFAULT 1000,
    p_page INT DEFAULT 1,
    p_order_by TEXT DEFAULT 'position.ASC'
)
RETURNS SETOF product_groups_response_type AS $$
    SELECT 
        n_i.id AS id,
        n_i.account_id AS account_id,
        n_i.name AS name,
        n_i.position AS position,
        n_i.status AS status,
        n_i.date_add AS date_add,
        n_i.date_edit AS date_edit,
        n_i.add_by AS add_by,
        n_i.edit_by AS edit_by,
        n_i.metadata AS metadata
    FROM product_groups n_i
    WHERE 
        -- 1. Text search across multiple fields
        (
            p_search_text IS NULL OR
            n_i.name ILIKE '%' || p_search_text || '%'
        )
        -- 2. Single 
        AND (p_id IS NULL OR n_i.id = ANY(p_id))
        AND (p_account_id IS NULL OR n_i.account_id = ANY(p_account_id))
        AND (p_status IS NULL OR n_i.status = ANY(p_status))

        -- 3. Array

        -- 4. Timestamp ranges

        -- 5. Numeric ranges

    ORDER BY 
        -- Dynamic ORDER BY parsing
        position ASC NULLS LAST, 
        id DESC  
        -- , last_online DESC -- , (summary->>'attitute')::INT DESC
    LIMIT p_per_page
    OFFSET p_per_page * (p_page - 1);
$$ LANGUAGE sql STABLE;


-- Public Function: Insert / Update Bill
CREATE OR REPLACE FUNCTION upsert_product_groups(
    p_product_groups JSONB
)
RETURNS SETOF product_groups
LANGUAGE plpgsql
AS $$
BEGIN

    RETURN QUERY
    WITH src AS (
        SELECT
            COALESCE(
                NULLIF(p->>'id', '')::UUID,
                gen_random_uuid()
            ) AS id,
            (p->>'account_id')::UUID AS account_id,
            p->>'name' AS name,
            NULLIF(p->>'position', '')::INTEGER AS position,
            COALESCE(
                p->>'status',
                'ACTIVE'
            ) AS status,
            COALESCE(
                NULLIF(p->>'date_add', '')::TIMESTAMPTZ,
                NOW()
            ) AS date_add,

            NOW() AS date_edit,

            (p->>'add_by')::UUID AS add_by,

            NULLIF(
                p->>'edit_by',
                ''
            )::UUID AS edit_by,

            p->'metadata' AS metadata

        FROM jsonb_array_elements(p_product_groups) p
    ),

    upserted AS (
        INSERT INTO product_groups (
            id,
            account_id,
            name,
            position,
            status,
            date_add,
            date_edit,
            add_by,
            edit_by,
            metadata
        )
        SELECT *
        FROM src

        ON CONFLICT (id)
        DO UPDATE SET
            account_id = EXCLUDED.account_id,
            name = EXCLUDED.name,
            position = EXCLUDED.position,
            status = EXCLUDED.status,
            date_edit = NOW(),
            edit_by = EXCLUDED.edit_by,
            metadata = EXCLUDED.metadata

        RETURNING *
    )

    SELECT *
    FROM upserted;

END;
$$;