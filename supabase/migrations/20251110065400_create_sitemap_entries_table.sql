CREATE TABLE sitemap_entries (
  id SERIAL PRIMARY KEY,
  type VARCHAR(50) NOT NULL DEFAULT 'PAGE', -- Type of url: 'PAGE', 'AREA_SUBJECT', 'SUBJECT', 'BLOG", "ADVERTISEMENT"
  url TEXT UNIQUE NOT NULL,
  lastmod TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
  -- optional
  changefreq VARCHAR(20),
  priority NUMERIC(2,1),
  date_add TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
  date_edit TIMESTAMP WITH TIME ZONE
);
alter table sitemap_entries enable row level security;
create policy "Enable read access for all sitemap_entries"
on "public"."sitemap_entries"
-- as PERMISSIVE
-- for ALL
to public
using (true);

