
DROP FUNCTION IF EXISTS get_accounts_v5_by_ranking;
DROP FUNCTION IF EXISTS get_accounts_v5;
DROP FUNCTION IF EXISTS get_accounts_v5_NEW;
DROP FUNCTION IF EXISTS import_accounts_v5_csv CASCADE;
SELECT pg_stat_clear_snapshot();

CREATE OR REPLACE FUNCTION get_accounts_v5_by_ranking(
    p_areas VARCHAR[] DEFAULT ARRAY[]::VARCHAR[],
    p_subjects VARCHAR[] DEFAULT ARRAY['USER']::VARCHAR[],
    p_type VARCHAR[] DEFAULT ARRAY[]::VARCHAR[],
    p_pro TEXT[] DEFAULT ARRAY[]::VARCHAR[],
    p_status TEXT[] DEFAULT ARRAY[]::VARCHAR[],
    p_page INT DEFAULT 1,
    p_pro_limit INT DEFAULT 40, 
    p_nonpro_limit INT DEFAULT 10
)
RETURNS SETOF accounts_v5 AS $$
WITH

    -- #1 VIP pool for requested page
    vip AS (
        SELECT *
        FROM accounts_v5
        WHERE
            (
                p_pro IS NULL
                OR p_pro = '{}'
                OR pro = ANY(p_pro)
            )
        AND (
                p_areas IS NULL
                OR p_areas = '{}'
                OR areas && p_areas
            )
        AND (
                p_subjects IS NULL
                OR p_subjects = '{}'
                OR subjects && p_subjects
            )
        AND (
                p_status IS NULL
                OR p_status = '{}'
                OR status = ANY(p_status)
            )
        AND (
                p_status IS NULL
                OR p_status = '{}'
                OR status = ANY(p_status)
            )
        AND (
                p_type IS NULL
                OR p_type = '{}'
                OR type = ANY(p_type)
            )
        ORDER BY rs DESC
        LIMIT p_pro_limit
        OFFSET (p_pro_limit * (p_page - 1))
    ),

    -- #2 VIP total count
    vip_endtal AS (
        SELECT COUNT(*) AS total
        FROM accounts_v5
        WHERE
            (p_pro IS NULL OR p_pro = '{}' OR pro = ANY(p_pro))
        AND (p_areas IS NULL OR p_areas = '{}' OR areas && p_areas)
        AND (p_subjects IS NULL OR p_subjects = '{}' OR subjects && p_subjects)
        AND (p_status IS NULL OR p_status = '{}' OR status = ANY(p_status))
    ),

    -- #3 nonvip total (needed for dynamic limit)
    nonvip_endtal AS (
        SELECT COUNT(*) AS total
        FROM accounts_v5
        WHERE
            NOT (p_pro IS NULL OR p_pro = '{}' OR pro = ANY(p_pro))
        AND (p_areas IS NULL OR p_areas = '{}' OR areas && p_areas)
        AND (p_subjects IS NULL OR p_subjects = '{}' OR subjects && p_subjects)
        AND (p_status IS NULL OR p_status = '{}' OR status = ANY(p_status))
    ),

    -- #4 Actual nonvip rows (now safe)
    nonvip AS (
        SELECT *
        FROM accounts_v5
        WHERE
            NOT (p_pro IS NULL OR p_pro = '{}' OR pro = ANY(p_pro))
        AND (p_areas IS NULL OR p_areas = '{}' OR areas && p_areas)
        AND (p_subjects IS NULL OR p_subjects = '{}' OR subjects && p_subjects)
        AND (p_status IS NULL OR p_status = '{}' OR status = ANY(p_status))
        ORDER BY rs DESC
        LIMIT (
            CASE
                WHEN (SELECT COUNT(*) FROM vip) = p_pro_limit
                    THEN p_nonpro_limit
                ELSE
                    p_pro_limit + p_nonpro_limit
                    - (SELECT COUNT(*) FROM vip)
            END
        )
    )

    SELECT * FROM vip
    UNION ALL
    SELECT * FROM nonvip;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION get_accounts_v5(
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

RETURNS SETOF accounts_v5 AS $$
    SELECT *
    FROM accounts_v5
    WHERE 
    
        -- 1. Text search across multiple fields
        (
            p_search_text IS NULL OR
            name ILIKE '%' || p_search_text || '%' OR
            fullname ILIKE '%' || p_search_text || '%' OR
            username ILIKE '%' || p_search_text || '%' OR
            phone ILIKE '%' || p_search_text || '%' OR
            email ILIKE '%' || p_search_text || '%' OR
            approach ILIKE '%' || p_search_text || '%' OR
            intro ILIKE '%' || p_search_text || '%' OR
            qua ILIKE '%' || p_search_text || '%'
        )
        -- 2. Status filter
        AND (p_id IS NULL OR id = ANY(p_id))
        AND (p_alias_id IS NULL OR alias_id = ANY(p_alias_id))
        AND (p_owner IS NULL OR owner = ANY(p_owner))
        AND (p_username IS NULL OR username = ANY(p_username))
        AND (p_email IS NULL OR email = ANY(p_email))
        AND (p_phone IS NULL OR phone = ANY(p_phone))
        AND (p_modes IS NULL OR modes && p_modes)
        AND (p_areas IS NULL OR areas && p_areas)
        AND (p_subjects IS NULL OR subjects && p_subjects)
        AND (p_pro IS NULL OR pro = ANY(p_pro))
        AND (p_status IS NULL OR status = ANY(p_status))
        AND (p_type IS NULL OR type = ANY(p_type))
        -- 3. Timestamp ranges
        AND (p_last_online_start IS NULL OR last_online >= p_last_online_start)
        AND (p_last_online_end   IS NULL OR last_online <= p_last_online_end)
        AND (p_last_login_start  IS NULL OR last_login >= p_last_login_start)
        AND (p_last_login_end    IS NULL OR last_login <= p_last_login_end)
        AND (p_last_update_start IS NULL OR last_update >= p_last_update_start)
        AND (p_last_update_end   IS NULL OR last_update <= p_last_update_end)

        -- 4. Numeric ranges
        AND (p_rs_min IS NULL OR rs >= p_rs_min)
        AND (p_rs_max IS NULL OR rs <= p_rs_max)
        AND (p_as_value_min IS NULL OR as_value >= p_as_value_min)
        AND (p_as_value_max IS NULL OR as_value <= p_as_value_max)

        -- 5. JSONB summary filtering
    -- badge: {
    --   teaching : 2,
    --   personality : 3,
    --   punctual : 0,
    --   happy : 0,
    --   fee : 5, 
    -- }
        AND (p_min_teaching IS NULL OR (badge->>'teaching')::INT >= p_min_teaching)
        AND (p_max_teaching IS NULL OR (badge->>'teaching')::INT <= p_max_teaching)
        AND (p_min_personality IS NULL OR (badge->>'personality')::INT >= p_min_personality)
        AND (p_max_personality IS NULL OR (badge->>'personality')::INT <= p_max_personality)
        AND (p_min_punctual IS NULL OR (badge->>'punctual')::INT >= p_max_punctual)
        AND (p_max_punctual IS NULL OR (badge->>'punctual')::INT <= p_max_punctual)
        AND (p_min_happy IS NULL OR (badge->>'happy')::INT >= p_min_happy)
        AND (p_max_happy IS NULL OR (badge->>'happy')::INT <= p_max_happy)
        AND (p_min_fee IS NULL OR (badge->>'fee')::INT >= p_min_fee)
        AND (p_max_fee IS NULL OR (badge->>'fee')::INT <= p_max_fee)
        AND (p_summary_contains IS NULL OR summary @> p_summary_contains)

        -- AND rs > 0
    ORDER BY 
        -- Dynamic ORDER BY parsing
        rs DESC NULLS LAST, 
        id DESC  
        -- , last_online DESC -- , (summary->>'attitute')::INT DESC
    LIMIT p_per_page
    OFFSET p_per_page * (p_page - 1);

$$ LANGUAGE sql STABLE;

-- Use for bulk upload of Account_V5 using CSV (parsed client-side)
CREATE OR REPLACE FUNCTION import_accounts_v5_csv(rows JSONB)
    RETURNS INTEGER
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        inserted_count INTEGER;
    BEGIN
       INSERT INTO accounts_v5 (
        alias_id,
        owner,
        name,
        fullname,
        username,
        email,
        phone,
        email_verified,
        phone_verified,
        last_login,
        last_update,
        status,
        pref,
        rs,
        as_value,
        as_info,
        pro,
        type,
        lang,
        user_no,
        provider_id,
        created_at,
        img,
        rate,
        rate_times,
        rate_final,
        badge,
        fee,
        fee_max,
        fee_type,
        currency,
        age,
        gender,
        address,
        area,
        place,
        qua,
        yr_exp,
        intro,
        approach,
        exp,
        areas,
        subjects,
        modes,
        timeslot,
        glplus,
        last_online,
        summary,
        policy,
        linked_accounting_org_id,
        linked_payroll_org_id,
        linked_member_id,
        gur_id,
        stu_ids,
        is_client,
        is_tutor,
        version
    )
    SELECT
        row->>'alias_id',
        row->>'owner',
        row->>'name',
        row->>'fullname',
        row->>'username',
        row->>'email',
        row->>'phone',
        (row->>'email_verified')::BOOLEAN,
        (row->>'phone_verified')::BOOLEAN,
        (row->>'last_login')::TIMESTAMP,
        (row->>'last_update')::TIMESTAMP,
        row->>'status',
        row->>'pref',
        (row->>'rs')::NUMERIC,
        (row->>'as_value')::NUMERIC,
        row->'as_info',
        row->>'pro',
        row->>'type',
        row->>'lang',
        (row->>'user_no')::INTEGER,
        row->>'provider_id',
        (row->>'created_at')::TIMESTAMP,
        row->>'img',
        (row->>'rate')::DOUBLE PRECISION,
        (row->>'rate_times')::DOUBLE PRECISION,
        (row->>'rate_final')::DOUBLE PRECISION,
        row->'badge',
        (row->>'fee')::DOUBLE PRECISION,
        (row->>'fee_max')::DOUBLE PRECISION,
        row->>'fee_type',
        row->>'currency',
        (row->>'age')::TIMESTAMP,
        row->>'gender',
        row->>'address',
        row->>'area',
        row->>'place',
        row->>'qua',
        (row->>'yr_exp')::TIMESTAMP,
        row->>'intro',
        row->>'approach',
        row->>'exp',
        COALESCE(
          ARRAY(
            SELECT jsonb_array_elements_text(row->'areas')
          ),
          ARRAY[]::TEXT[]
        ),
        COALESCE(
          ARRAY(
            SELECT jsonb_array_elements_text(row->'subjects')
          ),
          ARRAY[]::TEXT[]
        ),
        COALESCE(
          ARRAY(
            SELECT jsonb_array_elements_text(row->'modes')
          ),
          ARRAY[]::TEXT[]
        ),
        row->'timeslot',
        row->>'glplus',
        (row->>'last_online')::TIMESTAMP,
        row->'summary',
        row->'policy',
        (row->>'linked_accounting_org_id')::UUID,
        (row->>'linked_payroll_org_id')::UUID,
        (row->>'linked_member_id')::UUID,
        row->>'gur_id',
        COALESCE(
          ARRAY(
            SELECT jsonb_array_elements_text(row->'stu_ids')
          ),
          ARRAY[]::TEXT[]
        ),
        (row->>'is_client')::BOOLEAN,
        (row->>'is_tutor')::BOOLEAN,
        row->>'version'
    FROM jsonb_array_elements(rows) AS row
    WHERE row ? 'alias_id'
      AND row->>'alias_id' IS NOT NULL
    ON CONFLICT (alias_id) DO NOTHING;

    GET DIAGNOSTICS inserted_count = ROW_COUNT;
    RETURN inserted_count;
END;
$$;
