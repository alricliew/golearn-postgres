
DROP FUNCTION IF EXISTS get_sitemap2 CASCADE; 
create or replace function get_sitemap2(
  p_type text,
  p_page_no int default 0,
  p_limit int default 45000
)
returns table (
  id bigint,
  type varchar(50),
  url text,
  lastmod timestamptz,
  changefreq varchar(50),
  priority int,
  date_edit timestamptz
)
language sql
as $$
  select 
    id,
    type,
    url,
    lastmod,
    changefreq,
    priority,
    date_edit
  from sitemap_entries
  where type = p_type
  order by id
  limit p_limit
  offset p_page_no * p_limit;
$$;