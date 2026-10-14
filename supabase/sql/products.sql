
DROP FUNCTION IF EXISTS get_products;
DROP FUNCTION IF EXISTS upsert_products CASCADE; 

SELECT pg_stat_clear_snapshot();

CREATE OR REPLACE FUNCTION get_products(
    p_id UUID[] DEFAULT NULL,
    p_account_id UUID[] DEFAULT NULL,
    p_account_alias_id TEXT[] DEFAULT NULL,
    p_status VARCHAR[] DEFAULT NULL,
    p_slug TEXT[] DEFAULT NULL,
    p_tags VARCHAR[] DEFAULT NULL,
    p_categories VARCHAR[] DEFAULT NULL,
    p_subjects VARCHAR[] DEFAULT NULL,
    p_areas VARCHAR[] DEFAULT NULL,
    p_area VARCHAR[] DEFAULT NULL,
    p_group_id UUID[] DEFAULT NULL,
    p_variant_id UUID[] DEFAULT NULL,
    p_search_text TEXT DEFAULT NULL,
    p_per_page INT DEFAULT 1000,
    p_page INT DEFAULT 1,
    p_order_by TEXT DEFAULT 'position.ASC,date_edit.DESC'
)
RETURNS SETOF products_response_type AS $$
    SELECT 
        n_i.id AS id,
        n_i.account_id AS account_id,
        n_i.account_alias_id AS account_alias_id,
        n_i.status AS status,
        n_i.name AS name,
        n_i.slug AS slug,
        n_i.description AS description,
        n_i.images AS images,
        n_i.price::NUMERIC(12,2) AS price,
        n_i.currency AS currency,
        n_i.stock AS stock,
        n_i.tags AS tags,
        n_i.categories AS categories,
        n_i.subjects AS subjects,
        n_i.address AS address,
        n_i.areas AS areas,
        n_i.area AS area,
        n_i.place AS place,
        n_i.attributes AS attributes,
        n_i.note AS note,
        n_i.position AS position,  
        n_i.group_id AS group_id,
        n_i.variant_id AS variant_id,
        n_i.variant_attribute AS variant_attribute,
        n_i.is_default_variant AS is_default_variant,
        n_i.date_add AS date_add,
        n_i.date_edit AS date_edit,
        n_i.add_by AS add_by,
        n_i.edit_by AS edit_by,
        n_i.metadata AS metadata,
        pg.name AS group_name,
        pv.name AS variant_name,
        v_product_variants.variants AS product_variants
    FROM products n_i
    LEFT JOIN product_groups pg ON pg.id = n_i.group_id
    LEFT JOIN product_variants pv ON pv.id = n_i.variant_id
    LEFT JOIN LATERAL (
        SELECT jsonb_agg(
            jsonb_build_object(
                'id', ii.id,
                'account_id', ii.account_id,
                'account_alias_id', ii.account_alias_id,
                'status', ii.status,
                'name', ii.name,
                'slug', ii.slug,
                'description', ii.description,
                'images', ii.images,
                'price', ii.price,
                'currency', ii.currency,
                'stock', ii.stock,
                'tags', ii.tags,
                'categories', ii.categories,
                'subjects', ii.subjects,
                'address', ii.address,
                'areas', ii.areas,
                'area', ii.area,
                'place', ii.place,
                'attributes', ii.attributes,
                'note', ii.note,
                'position', ii.position,
                'variant_id', ii.variant_id,
                'variant_attribute', ii.variant_attribute,
                'is_default_variant', ii.is_default_variant,
                'date_add', ii.date_add,
                'date_edit', ii.date_edit,
                'add_by', ii.add_by,
                'edit_by', ii.edit_by,
                'metadata', ii.metadata
            )
        ) AS variants
        FROM products ii
        WHERE ii.variant_id = n_i.variant_id
    ) AS v_product_variants ON TRUE
    WHERE 
        -- 1. Text search across multiple fields
        (
            p_search_text IS NULL OR
            n_i.name ILIKE '%' || p_search_text || '%' OR
            n_i.description ILIKE '%' || p_search_text || '%'
        )
        -- 2. Single 
        AND (p_id IS NULL OR n_i.id = ANY(p_id))
        AND (p_account_id IS NULL OR n_i.account_id = ANY(p_account_id))
        AND (p_account_alias_id IS NULL OR n_i.account_alias_id = ANY(p_account_alias_id))
        AND (p_status IS NULL OR n_i.status = ANY(p_status))
        AND (p_slug IS NULL OR n_i.slug = ANY(p_slug))
        AND (p_area IS NULL OR n_i.area = ANY(p_area))
        AND (p_group_id IS NULL OR n_i.group_id = ANY(p_group_id))
        AND (p_variant_id IS NULL OR n_i.variant_id = ANY(p_variant_id))

        -- 3. Array
        AND (p_tags IS NULL OR n_i.tags && p_tags)
        AND (p_categories IS NULL OR n_i.categories && p_categories)
        AND (p_subjects IS NULL OR n_i.subjects && p_subjects)
        AND (p_areas IS NULL OR n_i.areas && p_areas)

        -- 4. Timestamp ranges

        -- 5. Numeric ranges

    ORDER BY 
        -- Dynamic ORDER BY parsing
        NULLIF(n_i.position, -1) ASC NULLS LAST,
        date_edit DESC NULLS LAST, 
        id DESC  
        -- , last_online DESC -- , (summary->>'attitute')::INT DESC
    LIMIT p_per_page
    OFFSET p_per_page * (p_page - 1);
$$ LANGUAGE sql STABLE;


-- Public Function: Insert / Update Products
CREATE OR REPLACE FUNCTION generate_unique_slug(input TEXT)
RETURNS TEXT AS $$
DECLARE
    base TEXT;
    final_slug TEXT;
BEGIN
    base := lower(regexp_replace(input, '[^a-zA-Z0-9]+', '-', 'g'));

    final_slug := base;

    WHILE EXISTS (SELECT 1 FROM products WHERE slug = final_slug) LOOP
        final_slug := base || '-' || substr(gen_random_uuid()::text, 1, 6);
    END LOOP;

    RETURN final_slug;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION upsert_products(
    p_products JSONB
)
RETURNS SETOF products
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
            p->>'account_alias_id' AS account_alias_id,
            COALESCE(
                p->>'status',
                'DRAFT'
            ) AS status,
            p->>'name' AS name,
            -- p->>'slug' AS slug,
            COALESCE(
                NULLIF(p->>'slug', ''),
                generate_unique_slug(p->>'name')
            ) AS slug,
            p->>'description' AS description,

            p->'images' AS images,

            NULLIF(p->>'price', '')::MONEY AS price,
            p->>'currency' AS currency,

            NULLIF(p->>'stock', '')::INTEGER AS stock,
            CASE
                WHEN jsonb_typeof(p->'tags') = 'array'
                THEN ARRAY(
                    SELECT jsonb_array_elements_text(p->'tags')
                )
                ELSE NULL
            END AS tags,
            CASE
                WHEN jsonb_typeof(p->'categories') = 'array'
                THEN ARRAY(
                    SELECT jsonb_array_elements_text(p->'categories')
                )
                ELSE NULL
            END AS categories,
            CASE
                WHEN jsonb_typeof(p->'subjects') = 'array'
                THEN ARRAY(
                    SELECT jsonb_array_elements_text(p->'subjects')
                )
                ELSE NULL
            END AS subjects,
            p->>'address' AS address,
            CASE
                WHEN jsonb_typeof(p->'areas') = 'array'
                THEN ARRAY(
                    SELECT jsonb_array_elements_text(p->'areas')
                )
                ELSE NULL
            END AS areas,
            p->>'area' AS area,
            p->>'place' AS place,

            p->'attributes' AS attributes,
            p->'note' AS note,
            NULLIF(p->>'position', '')::INTEGER AS position,
            NULLIF(
                p->>'group_id',
                ''
            )::UUID AS group_id,
            NULLIF(
                p->>'variant_id',
                ''
            )::UUID AS variant_id,

            p->'variant_attribute' AS variant_attribute,

            COALESCE(
                (p->>'is_default_variant')::BOOLEAN,
                TRUE
            ) AS is_default_variant,

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

        FROM jsonb_array_elements(p_products) p
    ),

    upserted AS (
        INSERT INTO products (
            id,
            account_id,
            account_alias_id,
            status,
            name,
            slug,
            description,
            images,
            price,
            currency,
            stock,
            tags,
            categories,
            subjects,
            address,
            areas,
            area,
            place,
            attributes,
            note,
            position,
            group_id,
            variant_id,
            variant_attribute,
            is_default_variant,
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
            account_alias_id = EXCLUDED.account_alias_id,
            status = EXCLUDED.status,
            name = EXCLUDED.name,
            slug = EXCLUDED.slug,
            description = EXCLUDED.description,
            images = EXCLUDED.images,
            price = EXCLUDED.price,
            currency = EXCLUDED.currency,
            stock = EXCLUDED.stock,
            tags = EXCLUDED.tags,
            categories = EXCLUDED.categories,
            subjects = EXCLUDED.subjects,
            address = EXCLUDED.address,
            areas = EXCLUDED.areas,
            area = EXCLUDED.area,
            place = EXCLUDED.place,
            attributes = EXCLUDED.attributes,
            note = EXCLUDED.note,
            position = EXCLUDED.position,
            group_id = EXCLUDED.group_id,
            variant_id = EXCLUDED.variant_id,
            variant_attribute = EXCLUDED.variant_attribute,
            is_default_variant = EXCLUDED.is_default_variant,
            date_edit = NOW(),
            edit_by = EXCLUDED.edit_by,
            metadata = EXCLUDED.metadata

        RETURNING *
    )

    SELECT *
    FROM upserted;

END;
$$;