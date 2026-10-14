

# Restore Remote DB 




# For Seeding The Sitemap SQL 

DB Password for Sitemap project
frWF9qZudnacp3mr

Dump (WORKING)
(For data)
npx supabase db dump --db-url "postgresql://postgres.actobwqzfqqklcavbudc:frWF9qZudnacp3mr@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres"  -f  supabase/seed2.sql --data-only
(For schema)
npx supabase db dump --db-url "postgresql://postgres.actobwqzfqqklcavbudc:frWF9qZudnacp3mr@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres"  -f  supabase/schema.sql


pg_dump Cmd (WORKING)
(Data + Schema + role)
pg_dump "postgresql://postgres.actobwqzfqqklcavbudc:frWF9qZudnacp3mr@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres" -F p -f supabase/supabase_backup_w_pg_dump.sql



pg_restore
psql "postgresql://postgres.actobwqzfqqklcavbudc:frWF9qZudnacp3mr@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres" -f supabase/supabase_backup_w_pg_dump.sql


## Import CSV from Supabase (Working)
Step by step:
1. Go to GL5 project >lib > supabase > seeding_csv.ts to generate the list of sitemap urls 
2. Run the psql command below to upload the csv to the remote postgres.
3. The postgres connection string is in supabase > direct connection (select pooler)

psql "postgresql://postgres.actobwqzfqqklcavbudc:frWF9qZudnacp3mr@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres" -c "\COPY sitemap_entries(id,type,url,lastmod,changefreq,priority,date_add,date_edit) FROM 'C:\Users\alric\Documents\Development\golearn\.next\server\app\[lang]\pricing\users_seed.csv' CSV HEADER;"



## Check for banned ip and unband (Fix Supabase CLI stuck at Initializing login...)
npx supabase network-restrictions --project-ref actobwqzfqqklcavbudc get --experimental
npx supabase network-bans get --project-ref actobwqzfqqklcavbudc --experimental

npx supabase network-bans remove --db-unban-ip 2406:da18:243:7402:76d1:441f:2b54:b1c3 --project-ref actobwqzfqqklcavbudc --experimental

Whitelist IP
npx supabase network-restrictions --project-ref actobwqzfqqklcavbudc update --db-allow-cidr 2406:da18:243:7402:76d1:441f:2b54:b1c3 --experimental

npx supabase network-restrictions --project-ref actobwqzfqqklcavbudc update --db-allow-cidr 0.0.0.0/0 --db-allow-cidr ::/0 --experimental


