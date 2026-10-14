CREATE TABLE accounts_v5 (
    id                      SERIAL PRIMARY KEY,
    alias_id                VARCHAR(255), -- Originally the firestore doc id
    owner                   VARCHAR(255),
    name                    VARCHAR(255),
    fullname                VARCHAR(255),
    username                VARCHAR(255),
    email                   VARCHAR(255),
    phone                   VARCHAR(50),
    email_verified           BOOLEAN,
    phone_verified           BOOLEAN,
    last_login              TIMESTAMP,
    last_update             TIMESTAMP,
    status                  VARCHAR(50),   -- AccountTutorStatus
    pref                    VARCHAR(50),   -- Preference
    rs                      NUMERIC,
    as_value                NUMERIC,
    as_info                 JSONB,          -- AsInfo
    pro                     VARCHAR(50),   -- ProStatus
    type                    VARCHAR(50),   -- AccountType
    lang                    VARCHAR(50),   -- Language
    user_no                 INTEGER,
    provider_id             VARCHAR(255),
    created_at              TIMESTAMP,
    img                     VARCHAR(512),
    rate                    NUMERIC,
    rate_times              INTEGER,
    rate_final              NUMERIC,
    badge                   JSONB,
    fee                     INTEGER,
    fee_max                 INTEGER,
    fee_type                VARCHAR(50),   -- FeeType
    currency                VARCHAR(10),   -- Currency
    age                     TIMESTAMP,
    gender                  VARCHAR(20),   -- Gender
    address                 TEXT,
    area                    VARCHAR(255),
    place                   VARCHAR(255),
    qua                     TEXT,
    yr_exp                  TIMESTAMP,
    intro                   TEXT,
    approach                TEXT,
    exp                     TEXT,
    areas                   TEXT[],
    subjects                TEXT[],
    modes                   TEXT[],         -- Mode enum values
    timeslot                JSONB,          -- Timeslot
    glplus                  VARCHAR(50),   -- GolearnPlusStatus
    last_online             TIMESTAMP,
    summary                 JSONB,          -- AccountSummary
    policy                  JSONB,          -- AccountPolicy
    linked_accounting_org_id VARCHAR(255),
    linked_payroll_org_id   VARCHAR(255),
    linked_member_id        VARCHAR(255),
    gur_id                  VARCHAR(255),
    stu_ids                 TEXT[],
    is_client               BOOLEAN,
    is_tutor                BOOLEAN,
    version                 VARCHAR(50)
);

alter table accounts_v5 enable row level security;
create policy "Enable read access for all accounts_v5"
on "public"."accounts_v5"
-- as PERMISSIVE
-- for ALL
to public
using (true);

DROP FUNCTION IF EXISTS get_accounts_v5_by_ranking;
CREATE OR REPLACE FUNCTION get_accounts_v5_by_ranking(
    p_areas VARCHAR[] DEFAULT ARRAY[]::VARCHAR[],
    p_subjects VARCHAR[] DEFAULT ARRAY[]::VARCHAR[],
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
            type = ANY('USER')
          ) 
    ORDER BY rs DESC
    LIMIT p_pro_limit
    OFFSET (p_pro_limit * (p_page - 1))
),

-- #2 VIP total count
vip_total AS (
    SELECT COUNT(*) AS total
    FROM accounts_v5
    WHERE
        (p_pro IS NULL OR p_pro = '{}' OR pro = ANY(p_pro))
      AND (p_areas IS NULL OR p_areas = '{}' OR areas && p_areas)
      AND (p_subjects IS NULL OR p_subjects = '{}' OR subjects && p_subjects)
      AND (p_status IS NULL OR p_status = '{}' OR status = ANY(p_status))
),

-- #3 nonvip total (needed for dynamic limit)
nonvip_total AS (
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

DROP FUNCTION IF EXISTS get_accounts_v5;
CREATE OR REPLACE FUNCTION get_accounts_v5(
    p_search_text TEXT DEFAULT NULL,             -- text search
    p_status TEXT[] DEFAULT NULL,           -- status filter
    p_type TEXT[] DEFAULT NULL,
    p_last_online_from TIMESTAMPTZ DEFAULT NULL,
    p_last_online_to TIMESTAMPTZ DEFAULT NULL,
    p_last_login_from TIMESTAMPTZ DEFAULT NULL,
    p_last_login_to TIMESTAMPTZ DEFAULT NULL,
    p_last_update_from TIMESTAMPTZ DEFAULT NULL,
    p_last_update_to TIMESTAMPTZ DEFAULT NULL,
    p_rs_min NUMERIC DEFAULT NULL,
    p_rs_max NUMERIC DEFAULT NULL,
    p_admin_score_min NUMERIC DEFAULT NULL,
    p_admin_score_max NUMERIC DEFAULT NULL,
    p_min_teaching INT DEFAULT NULL,             -- badge.teaching
    p_max_teaching INT DEFAULT NULL,
    p_min_personality INT DEFAULT NULL,        -- badge.personality
    p_max_personality INT DEFAULT NULL,
    p_min_punctual INT DEFAULT NULL,             -- badge.punctual
    p_max_punctual INT DEFAULT NULL,
    p_min_happy INT DEFAULT NULL,        -- badge.happy
    p_max_happy INT DEFAULT NULL,
    p_min_fee INT DEFAULT NULL,             -- badge.fee
    p_max_fee INT DEFAULT NULL,
    p_summary_contains JSONB DEFAULT NULL,       -- additional JSONB filters
    p_limit_count INT DEFAULT 50,
    p_offset_count INT DEFAULT 0
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
        email ILIKE '%' || p_search_text || '%'
    )

    -- 2. Status filter
    AND (
        p_status IS NULL OR status = ANY(p_status)
    )

    -- 3. Timestamp ranges
    AND (p_last_online_from IS NULL OR lastOnline >= p_last_online_from)
    AND (p_last_online_to   IS NULL OR lastOnline <= p_last_online_to)
    AND (p_last_login_from  IS NULL OR lastLogin >= p_last_login_from)
    AND (p_last_login_to    IS NULL OR lastLogin <= p_last_login_to)
    AND (p_last_update_from IS NULL OR lastUpdate >= p_last_update_from)
    AND (p_last_update_to   IS NULL OR lastUpdate <= p_last_update_to)

    -- 4. Numeric ranges
    AND (p_rs_min IS NULL OR rs >= p_rs_min)
    AND (p_rs_max IS NULL OR rs <= p_rs_max)
    AND (p_admin_score_min IS NULL OR adminScore >= p_admin_score_min)
    AND (p_admin_score_max IS NULL OR adminScore <= p_admin_score_max)

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

ORDER BY rs DESC, (summary->>'attitute')::INT DESC, lastOnline DESC
LIMIT p_limit_count
OFFSET p_offset_count;
$$ LANGUAGE sql STABLE;
