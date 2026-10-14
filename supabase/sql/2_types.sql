-- Product response type 
DROP TYPE IF EXISTS products_response_type CASCADE;
CREATE TYPE products_response_type AS (
    id UUID,
    account_id UUID,
    account_alias_id TEXT,
    status VARCHAR(255), -- DRAFT, ACTIVE, ARCHIVED
    name TEXT,
    slug TEXT,
    description TEXT,
    images JSONB,
    price NUMERIC,
    currency VARCHAR(3),
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
    is_default_variant BOOLEAN,
    date_add TIMESTAMPTZ,
    date_edit TIMESTAMPTZ,
    add_by UUID,
    edit_by UUID,
    metadata JSONB,

    -- Joins
    group_name TEXT,
    variant_name TEXT,
    product_variants JSONB
);

-- Product response type 
DROP TYPE IF EXISTS product_groups_response_type CASCADE;
CREATE TYPE product_groups_response_type AS (
    id UUID,
    account_id UUID,
    name TEXT,
    position INTEGER,
    status VARCHAR(255), -- ACTIVE, ARCHIVED
    date_add TIMESTAMPTZ,
    date_edit TIMESTAMPTZ,
    add_by UUID,
    edit_by UUID,
    metadata JSONB
)


DROP TYPE IF EXISTS promotions_response_type CASCADE;
CREATE TYPE promotions_response_type AS (
  id UUID,
  account_id UUID,
  status promotion_status,
  name TEXT,
  description TEXT,
  enabled BOOLEAN,
  priority INT,
  stackable BOOLEAN,
  exclusive BOOLEAN,
  metadata JSONB,
  schedule JSONB,
  limits JSONB,
  conditions JSONB,
  actions JSONB
);