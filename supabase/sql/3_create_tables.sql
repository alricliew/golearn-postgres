CREATE TABLE accounts_v5 (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alias_id VARCHAR(255) UNIQUE NOT NULL, -- Originally the firestore doc id
    owner VARCHAR(255),
    name VARCHAR(255),
    fullname VARCHAR(255),
    username VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(255),
    email_verified BOOLEAN,
    phone_verified BOOLEAN,
    last_login TIMESTAMP,
    last_update TIMESTAMP,
    status VARCHAR(50), 
    pref VARCHAR(50),   
    rs NUMERIC,
    as_value NUMERIC,  
    as_info JSONB,     
    pro VARCHAR(50),   
    type VARCHAR(50),  
    lang VARCHAR(50),  
    user_no INTEGER,
    provider_id TEXT,
    created_at TIMESTAMP,
    img TEXT,
    rate DOUBLE PRECISION,
    rate_times DOUBLE PRECISION,
    rate_final DOUBLE PRECISION,
    badge JSONB,
    fee DOUBLE PRECISION,
    fee_max DOUBLE PRECISION,
    fee_type VARCHAR(50), 
    currency VARCHAR(3), 
    age TIMESTAMP,
    gender VARCHAR(50),
    address TEXT,
    area VARCHAR(255),
    place VARCHAR(255),
    qua TEXT,
    yr_exp TIMESTAMP,
    intro TEXT,
    approach TEXT,
    exp TEXT,
    areas VARCHAR[],
    subjects VARCHAR[],
    modes VARCHAR[],
    timeslot JSONB, 
    glplus VARCHAR(50), 
    last_online TIMESTAMP,
    summary JSONB,
    policy JSONB, 
    linked_accounting_org_id UUID,
    linked_payroll_org_id UUID,
    linked_member_id UUID,
    gur_id TEXT,
    stu_ids TEXT[],
    is_client BOOLEAN,
    is_tutor BOOLEAN,
    version TEXT
);
alter table accounts_v5 enable row level security;
create policy "Enable read access for all accounts_v5"
on "public"."accounts_v5"
to public
using (true);

CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    account_alias_id TEXT,
    status VARCHAR(255) NOT NULL DEFAULT 'DRAFT', -- DRAFT, ACTIVE, ARCHIVED
    name TEXT NOT NULL,
    slug TEXT,
    description TEXT,
    images JSONB,
    price MONEY,
    currency VARCHAR(3) NOT NULL,
    stock INTEGER,
    tags VARCHAR(255)[],
    categories VARCHAR(255)[],
    subjects VARCHAR(255)[],
    address TEXT,
    areas VARCHAR(255)[],
    area VARCHAR(255),
    place TEXT,
    attributes JSONB,
    note TEXT, 
    position INTEGER,
    group_id UUID,
    variant_id UUID,
    variant_attribute JSONB,
    is_default_variant BOOLEAN NOT NULL DEFAULT TRUE,
    date_add TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    date_edit TIMESTAMPTZ,
    add_by UUID NOT NULL,
    edit_by UUID,
    metadata JSONB,
    CONSTRAINT uq_products_slug UNIQUE (slug)
);
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all products"
ON "public"."products"
TO public
USING (true);

-- DROP TABLE IF EXISTS product_groups CASCADE;
CREATE TABLE product_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    name TEXT NOT NULL,
    position INTEGER,
    status VARCHAR(255) NOT NULL DEFAULT 'ACTIVE', --ACTIVE, ARCHIVED
    date_add TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    date_edit TIMESTAMPTZ,
    add_by UUID NOT NULL,
    edit_by UUID,
    metadata JSONB
);
ALTER TABLE product_groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all product_groups"
ON "public"."product_groups"
TO public
USING (true);

-- DROP TABLE IF EXISTS product_group_relations CASCADE;
CREATE TABLE product_group_relations (
    product_id UUID NOT NULL,
    group_id UUID NOT NULL,

    PRIMARY KEY (group_id, product_id),

    CONSTRAINT fk_group_products_variant
        FOREIGN KEY (group_id)
        REFERENCES product_groups(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_group_products_product
        FOREIGN KEY (product_id)
        REFERENCES products(id)
        ON DELETE CASCADE
);
ALTER TABLE product_group_relations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all product_group_relations"
ON "public"."product_group_relations"
TO public
USING (true);

-- DROP TABLE IF EXISTS product_variants CASCADE;
CREATE TABLE product_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    name TEXT NOT NULL,
    position INTEGER,
    status VARCHAR(255) NOT NULL DEFAULT 'ACTIVE', --ACTIVE, ARCHIVED
    date_add TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    date_edit TIMESTAMPTZ,
    add_by UUID NOT NULL,
    edit_by UUID,
    metadata JSONB
);
ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all product_variants"
ON "public"."product_variants"
TO public
USING (true);

-- DROP TABLE IF EXISTS product_variant_relations CASCADE;
CREATE TABLE product_variant_relations (
    variant_id UUID NOT NULL,
    product_id UUID NOT NULL,

    PRIMARY KEY (variant_id, product_id),

    CONSTRAINT fk_variant_products_variant
        FOREIGN KEY (variant_id)
        REFERENCES product_variants(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_variant_products_product
        FOREIGN KEY (product_id)
        REFERENCES products(id)
        ON DELETE CASCADE
);
ALTER TABLE product_variant_relations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all product_variant_relationsv"
ON "public"."product_variant_relations"
TO public
USING (true);


------------------------------------------
-- PROMOTION
------------------------------------------
DROP TABLE IF EXISTS promotions CASCADE;
CREATE TABLE promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL, --  DEFAULT 'DRAFT'
        -- CHECK (status IN ('DRAFT', 'ACTIVE', 'ARCHIVED')),
    name TEXT NOT NULL,
    description TEXT DEFAULT NULL,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    priority INTEGER NOT NULL DEFAULT -1,
    stackable BOOLEAN NOT NULL DEFAULT FALSE,
    exclusive BOOLEAN NOT NULL DEFAULT FALSE,
    date_add TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    date_edit TIMESTAMPTZ DEFAULT NOW(),
    add_by UUID NOT NULL,
    edit_by UUID,
    metadata JSONB DEFAULT NULL
);
ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all promotions"
ON "public"."promotions"
TO public
USING (true);

DROP TABLE IF EXISTS promotion_conditions CASCADE;
CREATE TABLE promotion_conditions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id UUID NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    operator VARCHAR(30) NOT NULL,
    value JSONB NOT NULL
);
ALTER TABLE promotion_conditions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all promotion_conditions"
ON "public"."promotion_conditions"
TO public
USING (true);

DROP TABLE IF EXISTS promotion_actions CASCADE;
CREATE TABLE promotion_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id UUID NOT NULL,
    type VARCHAR(50) NOT NULL,
    value JSONB NOT NULL,
    priority INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT fk_promotion_actions_promotion
        FOREIGN KEY (promotion_id)
        REFERENCES promotions(id)
        ON DELETE CASCADE
);
ALTER TABLE promotion_actions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all promotion_actions"
ON "public"."promotion_actions"
TO public
USING (true);

DROP TABLE IF EXISTS promotion_schedules CASCADE;
CREATE TABLE promotion_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id UUID NOT NULL,
    date_start TIMESTAMPTZ,
    date_end TIMESTAMPTZ,
    day_of_weeks VARCHAR(50)[],
    hour_of_days VARCHAR(50)[],
    CONSTRAINT fk_promotion_schedules_promotion
        FOREIGN KEY (promotion_id)
        REFERENCES promotions(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_schedule_date_range
        CHECK (
            date_start IS NULL
            OR date_end IS NULL
            OR date_start <= date_end
        )
);
ALTER TABLE promotion_schedules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all promotion_schedules"
ON "public"."promotion_schedules"
TO public
USING (true);

DROP TABLE IF EXISTS promotion_limits CASCADE;
CREATE TABLE promotion_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id UUID NOT NULL,
    max_global_uses NUMERIC NULL,
    max_uses_per_customer NUMERIC NULL,
    max_discount_amount NUMERIC(18,2) NULL,
    budget_limit NUMERIC(18,2) NULL,

    CONSTRAINT fk_promotion_limits_promotion
        FOREIGN KEY (promotion_id)
        REFERENCES promotions(id)
        ON DELETE CASCADE,

    CONSTRAINT uq_promotion_limits_promotion
        UNIQUE (promotion_id),

    CONSTRAINT chk_max_global_uses
        CHECK (
            max_global_uses IS NULL
            OR max_global_uses >= 0
        ),

    CONSTRAINT chk_max_uses_per_customer
        CHECK (
            max_uses_per_customer IS NULL
            OR max_uses_per_customer >= 0
        ),

    CONSTRAINT chk_max_discount_amount
        CHECK (
            max_discount_amount IS NULL
            OR max_discount_amount >= 0
        ),

    CONSTRAINT chk_budget_limit
        CHECK (
            budget_limit IS NULL
            OR budget_limit >= 0
        )
);
ALTER TABLE promotion_limits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all promotion_limits"
ON "public"."promotion_limits"
TO public
USING (true);


------------------------------------------
-- LOG
------------------------------------------
CREATE TABLE logs_v5 (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uid         TEXT,                                      
    level       VARCHAR(50),                               
    description TEXT,                                      
    operation   VARCHAR(50),                               
    table_name  TEXT,                                      
    uri         TEXT,                                      
    date_add    TIMESTAMPTZ DEFAULT NOW(),                 
    metadata    JSONB,                                     
    old_data    JSONB,                                     
    new_data    JSONB                                      
);

CREATE EXTENSION IF NOT EXISTS pgcrypto;


CREATE TABLE sitemap_entries (
  id bigint PRIMARY KEY generated by default as identity not null,
  type VARCHAR(50) NOT NULL DEFAULT 'PAGE', -- Type of url: 'PAGE', 'AREA_SUBJECT', 'SUBJECT', 'BLOG", "ADVERTISEMENT"
  url TEXT UNIQUE NOT NULL,
  lastmod TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
  changefreq VARCHAR(20),
  priority NUMERIC(2,1),
  date_add TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
  date_edit TIMESTAMP WITH TIME ZONE
);
alter table sitemap_entries enable row level security;
create policy "Enable read access for all sitemap_entries"
on "public"."sitemap_entries"
to public
using (true);
-- Index for type + id (for keyset / last_id pagination)
CREATE INDEX IF NOT EXISTS idx_sitemap_type_id ON sitemap_entries(type, id);


-- TO BE DEPRECITATED -Timeout 
-- Create material view for efficient sitemap query
CREATE MATERIALIZED VIEW IF NOT EXISTS sitemap_row_numbers AS
SELECT
  id,
  type,
  url,
  lastmod,
  changefreq,
  priority,
  date_add,
  date_edit,
  ROW_NUMBER() OVER (PARTITION BY type ORDER BY id) AS rn
FROM sitemap_entries;

-- Index to make range queries by row number fast
CREATE INDEX IF NOT EXISTS idx_sitemap_rn ON sitemap_row_numbers(type, rn);

-- IMPORTANT
-- Always manually refresh the materialized view for row-number pagination after new sitemap_entries inserted
-- REFRESH MATERIALIZED VIEW sitemap_row_numbers;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY sitemap_row_numbers;


-- New implementation for scalable billions rows
-- Arbitrary Page Access using ppage cursors. When ever insert
CREATE TABLE sitemap_page_cursors (
    type TEXT NOT NULL,
    page_number INT NOT NULL,
    start_id BIGINT NOT NULL,
    PRIMARY KEY (type, page_number)
);
