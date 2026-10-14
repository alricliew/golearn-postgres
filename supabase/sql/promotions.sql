DROP FUNCTION IF EXISTS get_promotions;
DROP FUNCTION IF EXISTS upsert_promotion CASCADE; 

SELECT pg_stat_clear_snapshot();

CREATE OR REPLACE FUNCTION get_promotions(
    p_id UUID[] DEFAULT NULL,
    p_account_id UUID[] DEFAULT NULL,
    p_status VARCHAR[] DEFAULT NULL,
    p_search_text TEXT DEFAULT NULL,
    p_per_page INT DEFAULT 1000,
    p_page INT DEFAULT 1,
    p_order_by TEXT DEFAULT 'created_at.DESC'
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    result JSONB;
BEGIN

    SELECT jsonb_agg(row_to_json(t))
    INTO result
    FROM (
        SELECT
            n_i.id,
            n_i.account_id,
            n_i.status,
            n_i.name,
            n_i.description,
            n_i.enabled,
            n_i.priority,
            n_i.stackable,
            n_i.exclusive,
            n_i.metadata,

            -- schedule (1:1 JSON)
            (
                SELECT to_jsonb(s)
                FROM promotion_schedules s
                WHERE s.promotion_id = n_i.id
            ) AS schedule,

            -- limits (1:1 JSON)
            (
                SELECT to_jsonb(l)
                FROM promotion_limits l
                WHERE l.promotion_id = n_i.id
            ) AS limits,

            -- conditions (JSON array)
            COALESCE(
                (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'id', c.id,
                            'type', c.type,
                            'operator', c.operator,
                            'value', c.value
                        )
                    )
                    FROM promotion_conditions c
                    WHERE c.promotion_id = n_i.id
                ),
                '[]'::jsonb
            ) AS conditions,

            -- actions (JSON array)
            COALESCE(
                (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'id', a.id,
                            'type', a.type,
                            'value', a.value,
                            'priority', a.priority
                        )
                        ORDER BY a.priority ASC NULLS LAST
                    )
                    FROM promotion_actions a
                    WHERE a.promotion_id = n_i.id
                ),
                '[]'::jsonb
            ) AS actions

        FROM promotions n_i
        WHERE
            (
                p_search_text IS NULL OR
                n_i.name ILIKE '%' || p_search_text || '%' OR
                n_i.description ILIKE '%' || p_search_text || '%'
            )
            AND (p_id IS NULL OR n_i.id = ANY(p_id))
            AND (p_account_id IS NULL OR n_i.account_id = ANY(p_account_id))
            AND (p_status IS NULL OR n_i.status = ANY(p_status))

        ORDER BY
            n_i.priority DESC NULLS LAST,
            n_i.date_add DESC

        LIMIT p_per_page
        OFFSET p_per_page * (p_page - 1)

    ) t;

    RETURN COALESCE(result, '[]'::jsonb);
END;
$$;
--  Upsert input payload 
-- {
--   "id": null,
--   "account_id": "...",
--   "status": "ACTIVE",
--   "name": "10% Off",
--   "description": "...",
--   "enabled": true,
--   "priority": 10,
--   "stackable": false,
--   "exclusive": true,
--   "metadata": {},

--   "schedule": {
--     "date_start": "...",
--     "date_end": "...",
--     "day_of_weeks": ["MON","TUE"],
--     "day_of_weeks": ["01","09"],
--   },

--   "limits": {
--     "max_global_uses": 100,
--     "max_uses_per_customer": 2,
--     "budget_limit": 1000
--   },

--   "conditions": [
--     {
--       "type":"CUSTOMER_GROUP",
--       "operator":"IN",
--       "value":["VIP"]
--     }
--   ],

--   "actions":[
--     {
--       "type":"PERCENT_DISCOUNT",
--       "priority":1,
--       "value":{"percent":10}
--     }
--   ]
-- }

CREATE OR REPLACE FUNCTION upsert_promotion(
    p_promotion JSONB,
    p_user_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_promotion_id UUID;
    v_condition JSONB;
    v_action JSONB;
BEGIN
    -- RAISE EXCEPTION 'p_promotion % %', p_promotion;

    ----------------------------------------------------
    -- Promotion
    ----------------------------------------------------
    v_promotion_id :=
        COALESCE(
            (p_promotion->>'id')::uuid,
            gen_random_uuid()
        );
    -- RAISE EXCEPTION 'v_promotion_id % % %', (p_promotion->>'id')::uuid, v_promotion_id, p_promotion;

    INSERT INTO promotions (
        id,
        account_id,
        status,
        name,
        description,
        enabled,
        priority,
        stackable,
        exclusive,
        metadata,
        date_add,
        date_edit,
        add_by,
        edit_by
    )
    VALUES (
        v_promotion_id,
        (p_promotion->>'account_id')::uuid,
        p_promotion->>'status',
        p_promotion->>'name',
        p_promotion->>'description',
        COALESCE((p_promotion->>'enabled')::boolean,false),
        COALESCE((p_promotion->>'priority')::int,-1),
        COALESCE((p_promotion->>'stackable')::boolean,false),
        COALESCE((p_promotion->>'exclusive')::boolean,false),
        p_promotion->'metadata',
        now(),
        now(),
        p_user_id,
        p_user_id
    )
    ON CONFLICT (id)
    DO UPDATE
    SET
        status = EXCLUDED.status,
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        enabled = EXCLUDED.enabled,
        priority = EXCLUDED.priority,
        stackable = EXCLUDED.stackable,
        exclusive = EXCLUDED.exclusive,
        metadata = EXCLUDED.metadata,
        date_edit = now(),
        edit_by = p_user_id;

    -- RAISE EXCEPTION 'Schedule';
    ----------------------------------------------------
    -- Schedule
    ----------------------------------------------------

    DELETE FROM promotion_schedules
    WHERE promotion_id = v_promotion_id;

    IF p_promotion ? 'schedule' THEN

        INSERT INTO promotion_schedules(
            promotion_id,
            date_start,
            date_end,
            day_of_weeks,
            hour_of_days
        )
        VALUES(
            v_promotion_id,
            NULLIF(p_promotion->'schedule'->>'date_start', '')::timestamptz,
            NULLIF(p_promotion->'schedule'->>'date_end', '')::timestamptz,
            ARRAY(
                SELECT jsonb_array_elements_text(
                    p_promotion->'schedule'->'day_of_weeks'
                )
            ),
            ARRAY(
                SELECT jsonb_array_elements_text(
                    p_promotion->'schedule'->'hour_of_days'
                )
            )
        );

    END IF;

    ----------------------------------------------------
    -- Limits
    ----------------------------------------------------

    DELETE FROM promotion_limits
    WHERE promotion_id = v_promotion_id;

    IF p_promotion ? 'limits' THEN

        INSERT INTO promotion_limits(
            promotion_id,
            max_global_uses,
            max_uses_per_customer,
            max_discount_amount,
            budget_limit
        )
        VALUES(
            v_promotion_id,
            (p_promotion->'limits'->>'max_global_uses')::numeric,
            (p_promotion->'limits'->>'max_uses_per_customer')::numeric,
            (p_promotion->'limits'->>'max_discount_amount')::numeric,
            (p_promotion->'limits'->>'budget_limit')::numeric
        );

    END IF;

    ----------------------------------------------------
    -- Conditions
    ----------------------------------------------------

    DELETE FROM promotion_conditions
    WHERE promotion_id = v_promotion_id;

    FOR v_condition IN
        SELECT *
        FROM jsonb_array_elements(
            COALESCE(
                p_promotion->'conditions',
                '[]'::jsonb
            )
        )
    LOOP

        INSERT INTO promotion_conditions(
            promotion_id,
            type,
            operator,
            value
        )
        VALUES(
            v_promotion_id,
            v_condition->>'type',
            v_condition->>'operator',
            v_condition->'value'
        );

    END LOOP;
    ----------------------------------------------------
    -- Actions
    ----------------------------------------------------

    DELETE FROM promotion_actions
    WHERE promotion_id = v_promotion_id;

    FOR v_action IN
        SELECT *
        FROM jsonb_array_elements(
            COALESCE(
                p_promotion->'actions',
                '[]'::jsonb
            )
        )
    LOOP

        INSERT INTO promotion_actions(
            promotion_id,
            type,
            value,
            priority
        )
        VALUES(
            v_promotion_id,
            v_action->>'type',
            v_action->'value',
            COALESCE((v_action->>'priority')::int,0)
        );

    END LOOP;

    RETURN v_promotion_id;

END;
$$;