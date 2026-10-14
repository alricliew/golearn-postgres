CREATE OR REPLACE FUNCTION get_user_with_ranking(
    p_filter_areas     VARCHAR[] DEFAULT ARRAY[]::VARCHAR[],
    p_filter_subjects  VARCHAR[] DEFAULT ARRAY[]::VARCHAR[],
    p_vip_pro_list     TEXT[]    DEFAULT ARRAY[]::VARCHAR[],
    p_status_list      TEXT[]    DEFAULT ARRAY['active','inactive'],
    p_page             INT       DEFAULT 1,
    p_vip_limit        INT       DEFAULT 40,
    p_nonvip_limit     INT       DEFAULT 10
)
RETURNS SETOF tutor_v5 AS $$
WITH

-- #1 VIP pool for requested page
vip AS (
    SELECT *
    FROM tutor_v5
    WHERE pro = ANY(p_vip_pro_list)
      AND (p_filter_areas = '{}' OR areas && p_filter_areas)
      AND (p_filter_subjects = '{}' OR subjects && p_filter_subjects)
      AND status = ANY(p_status_list)
    ORDER BY rs DESC
    LIMIT p_vip_limit
    OFFSET (p_vip_limit * (p_page - 1))
),

-- #2 VIP total count
vip_total AS (
    SELECT COUNT(*) AS total
    FROM tutor_v5
    WHERE pro = ANY(p_vip_pro_list)
      AND (p_filter_areas = '{}' OR areas && p_filter_areas)
      AND (p_filter_subjects = '{}' OR subjects && p_filter_subjects)
      AND status = ANY(p_status_list)
),

-- #3 nonvip total (needed for dynamic limit)
nonvip_total AS (
    SELECT COUNT(*) AS total
    FROM tutor_v5
    WHERE NOT (pro = ANY(p_vip_pro_list))
      AND (p_filter_areas = '{}' OR areas && p_filter_areas)
      AND (p_filter_subjects = '{}' OR subjects && p_filter_subjects)
      AND status = ANY(p_status_list)
),

-- #4 Actual nonvip rows (now safe)
nonvip AS (
    SELECT *
    FROM tutor_v5
    WHERE NOT (pro = ANY(p_vip_pro_list))
      AND (p_filter_areas = '{}' OR areas && p_filter_areas)
      AND (p_filter_subjects = '{}' OR subjects && p_filter_subjects)
      AND status = ANY(p_status_list)
    ORDER BY rs DESC
    LIMIT (
        CASE
            WHEN (SELECT COUNT(*) FROM vip) = p_vip_limit
                THEN p_nonvip_limit
            ELSE
                -- fill to (vip_limit + nonvip_limit)
                p_vip_limit + p_nonvip_limit
                - (SELECT COUNT(*) FROM vip)
        END
    )
)

SELECT * FROM vip
UNION ALL
SELECT * FROM nonvip;
$$ LANGUAGE sql STABLE;
