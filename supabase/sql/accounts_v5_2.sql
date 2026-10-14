DROP FUNCTION IF EXISTS get_accounts_v5_new;
DROP FUNCTION IF EXISTS get_accounts_v5_NEW;

SELECT pg_stat_clear_snapshot();

-- New Get Account v5
CREATE OR REPLACE FUNCTION get_accounts_v5_new(
    p_id UUID[] DEFAULT NULL,
    p_alias_id VARCHAR[255] DEFAULT NULL,
    p_owner VARCHAR[255] DEFAULT NULL,
    p_username VARCHAR[255] DEFAULT NULL,
    p_email VARCHAR[255] DEFAULT NULL,
    p_phone VARCHAR[255] DEFAULT NULL,

    p_modes VARCHAR[] DEFAULT NULL,
    p_areas VARCHAR[] DEFAULT NULL,
    p_subjects VARCHAR[] DEFAULT NULL,
    p_pro VARCHAR[] DEFAULT NULL,
    p_status VARCHAR[] DEFAULT NULL,
    p_type VARCHAR[] DEFAULT NULL,

    p_last_online_start DATE DEFAULT NULL,
    p_last_online_end DATE DEFAULT NULL,
    p_last_login_start DATE DEFAULT NULL,
    p_last_login_end DATE DEFAULT NULL,
    p_last_update_start DATE DEFAULT NULL,
    p_last_update_end DATE DEFAULT NULL,

    p_rs_min NUMERIC DEFAULT NULL,
    p_rs_max NUMERIC DEFAULT NULL,
    p_as_value_min NUMERIC DEFAULT NULL,
    p_as_value_max NUMERIC DEFAULT NULL,

    p_min_teaching NUMERIC DEFAULT NULL,
    p_max_teaching NUMERIC DEFAULT NULL,
    p_min_personality NUMERIC DEFAULT NULL,
    p_max_personality NUMERIC DEFAULT NULL,
    p_min_punctual NUMERIC DEFAULT NULL,
    p_max_punctual NUMERIC DEFAULT NULL,
    p_min_happy NUMERIC DEFAULT NULL,
    p_max_happy NUMERIC DEFAULT NULL,
    p_min_fee DOUBLE PRECISION DEFAULT NULL,
    p_max_fee DOUBLE PRECISION DEFAULT NULL,

    p_summary_contains JSONB DEFAULT NULL,
    p_search_text TEXT DEFAULT NULL,

    p_per_page INT DEFAULT 9,
    p_page INT DEFAULT 1,

    p_order_by TEXT DEFAULT 'rs.DESC,last_online.DESC'
)
RETURNS SETOF accounts_v5
LANGUAGE plpgsql
AS $$

DECLARE
    v_order_part TEXT;
    v_order_parts TEXT[];
    v_order_clause TEXT := '';
    v_where_query TEXT := '';
    v_sql TEXT := '';
    i INT;
    
BEGIN

    -- =========================
    -- ORDER BY (SAFE)
    -- =========================
    v_order_parts := string_to_array(p_order_by, ',');

    FOR i IN 1..COALESCE(array_length(v_order_parts,1),0) LOOP

        v_order_part := trim(v_order_parts[i]);

        IF v_order_part LIKE 'rs.%' THEN
            v_order_clause := v_order_clause || 'rs ' ||
                upper(split_part(v_order_part, '.', 2)) || ' NULLS LAST, ';

        ELSIF v_order_part LIKE 'last_online.%' THEN
            v_order_clause := v_order_clause || 'last_online ' ||
                upper(split_part(v_order_part, '.', 2)) || ' NULLS LAST, ';

        ELSIF v_order_part LIKE 'last_login.%' THEN
            v_order_clause := v_order_clause || 'last_login ' ||
                upper(split_part(v_order_part, '.', 2)) || ' NULLS LAST, ';

        ELSIF v_order_part LIKE 'last_update.%' THEN
            v_order_clause := v_order_clause || 'last_update ' ||
                upper(split_part(v_order_part, '.', 2)) || ' NULLS LAST, ';

        ELSIF v_order_part LIKE 'as_value.%' THEN
            v_order_clause := v_order_clause || 'as_value ' ||
                upper(split_part(v_order_part, '.', 2)) || ' NULLS LAST, ';

        ELSIF v_order_part LIKE 'fee.%' THEN
            v_order_clause := v_order_clause || 'fee ' ||
                upper(split_part(v_order_part, '.', 2)) || ' NULLS LAST, ';

        ELSIF v_order_part LIKE 'status.%' THEN
            v_order_clause := v_order_clause || 'CASE WHEN status = ''' ||
                split_part(v_order_part, '.', 2) ||
                ''' THEN ' || i ||
                ' ELSE ' || (array_length(v_order_parts,1)+1) ||
                ' END, ';
        END IF;

    END LOOP;

    IF v_order_clause = '' THEN
        v_order_clause := 'rs DESC NULLS LAST, last_online DESC NULLS LAST'; -- 'last_online DESC NULLS LAST'; -- 'rs DESC NULLS LAST, last_online DESC NULLS LAST';
    ELSE
        v_order_clause := left(v_order_clause, length(v_order_clause) - 2);
    END IF;
    -- =========================
    -- WHERE
    -- =========================
    v_where_query := 'WHERE TRUE';

    -- text search
    IF p_search_text IS NOT NULL AND p_search_text <> '' THEN
        v_where_query := v_where_query || format(
            ' AND (
                name ILIKE %L OR
                fullname ILIKE %L OR
                username ILIKE %L OR
                phone ILIKE %L OR
                email ILIKE %L OR
                approach ILIKE %L OR
                intro ILIKE %L OR
                qua ILIKE %L
            )',
            '%'||p_search_text||'%',
            '%'||p_search_text||'%',
            '%'||p_search_text||'%',
            '%'||p_search_text||'%',
            '%'||p_search_text||'%',
            '%'||p_search_text||'%',
            '%'||p_search_text||'%',
            '%'||p_search_text||'%'
        );
    END IF;

    -- scalar filters
    IF p_id IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND id = ANY(%L::uuid[])', p_id);
    END IF;

    IF p_alias_id IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND alias_id = ANY(%L::varchar[])', p_alias_id);
    END IF;

    IF p_owner IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND owner = ANY(%L::varchar[])', p_owner);
    END IF;

    IF p_username IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND username = ANY(%L::varchar[])', p_username);
    END IF;

    IF p_email IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND email = ANY(%L::varchar[])', p_email);
    END IF;

    IF p_phone IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND phone = ANY(%L::varchar[])', p_phone);
    END IF;

    -- array filters
    IF p_modes IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND modes && %L::varchar[]', p_modes);
    END IF;

    IF p_areas IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND areas && %L::varchar[]', p_areas);
    END IF;

    IF p_subjects IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND subjects && %L::varchar[]', p_subjects);
    END IF;

    IF p_pro IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND pro && %L::varchar[]', p_pro);
    END IF;

    IF p_type IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND type && %L::varchar[]', p_type);
    END IF;

    IF p_status IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND status = ANY(%L::varchar[])', p_status);
    END IF;

    -- timestamps
    IF p_last_online_start IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND last_online >= %L', p_last_online_start);
    END IF;

    IF p_last_online_end IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND last_online <= %L', p_last_online_end);
    END IF;

    IF p_last_login_start IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND last_login >= %L', p_last_login_start);
    END IF;

    IF p_last_login_end IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND last_login <= %L', p_last_login_end);
    END IF;

    IF p_last_update_start IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND last_update >= %L', p_last_update_start);
    END IF;

    IF p_last_update_end IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND last_update <= %L', p_last_update_end);
    END IF;

    -- numeric ranges
    IF p_rs_min IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND rs >= %L', p_rs_min);
    END IF;

    IF p_rs_max IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND rs <= %L', p_rs_max);
    END IF;

    IF p_as_value_min IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND as_value >= %L', p_as_value_min);
    END IF;

    IF p_as_value_max IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND as_value <= %L', p_as_value_max);
    END IF;

    -- badge filters
    IF p_min_teaching IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND (badge->>''teaching'')::int >= %L', p_min_teaching);
    END IF;

    IF p_max_teaching IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND (badge->>''teaching'')::int <= %L', p_max_teaching);
    END IF;

    IF p_min_personality IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND (badge->>''personality'')::int >= %L', p_min_personality);
    END IF;

    IF p_max_personality IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND (badge->>''personality'')::int <= %L', p_max_personality);
    END IF;

    IF p_min_punctual IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND (badge->>''punctual'')::int >= %L', p_min_punctual);
    END IF;

    IF p_max_punctual IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND (badge->>''punctual'')::int <= %L', p_max_punctual);
    END IF;

    IF p_min_happy IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND (badge->>''happy'')::int >= %L', p_min_happy);
    END IF;

    IF p_max_happy IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND (badge->>''happy'')::int <= %L', p_max_happy);
    END IF;

    IF p_min_fee IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND (badge->>''fee'')::int >= %L', p_min_fee);
    END IF;

    IF p_max_fee IS NOT NULL THEN
        v_where_query := v_where_query || format(' AND (badge->>''fee'')::int <= %L', p_max_fee);
    END IF;

    -- JSONB summary filter
    IF p_summary_contains IS NOT NULL THEN
        v_where_query := v_where_query || ' AND summary @> ' || quote_literal(p_summary_contains);
    END IF;

    -- =========================
    -- FINAL QUERY
    -- =========================
    v_sql := format(
        'SELECT * FROM accounts_v5 %s ORDER BY %s LIMIT %s OFFSET %s',
        v_where_query,
        v_order_clause,
        p_per_page,
        (p_page - 1) * p_per_page
    );

    RETURN QUERY EXECUTE v_sql;

END;
$$;