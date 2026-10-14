INSERT INTO 
public.sitemap_entries (id, 
type,
url,
lastmod,
changefreq,
priority)
VALUES
(DEFAULT, 'STATIC', '/asdaisd/adqadas', CURRENT_DATE, DEFAULT, DEFAULT),
(DEFAULT, 'AREA_SUBJECT', '/xxx/xx', '2023-10-27T10:30:00Z', DEFAULT, DEFAULT);

INSERT INTO public.tutor_v5 (
    uid, name, fullname, username, email, phone,
    emailVerified, phoneVerified,
    lastLogin, lastUpdate,
    status, pref, rs, adminScore, adminScoreInfo,
    pro, type, lang,
    userNo, providerId, createdAt,
    img, rate, rateTimes, rateFinal,
    badge, fee, feeMax, feeType, currency,
    age, gender, address, area, place,
    qua, yrExp, intro, approach,
    areas, subjects, modes,
    timeslot, glplus, lastOnline,
    summary, policy,
    linkedAccountingOrgId, linkedPayrollOrgId, linkedMemberId
)
SELECT
    -- uid, names, etc.
    gen_random_uuid()::text AS uid,
    'User' || generate_series AS name,
    'User Fullname ' || generate_series AS fullname,
    'username_' || generate_series AS username,
    'user' || generate_series || '@example.com' AS email,
    '012345678' || (10 + generate_series)::text AS phone,

    -- verification
    (RANDOM() < 0.5) AS emailVerified,
    (RANDOM() < 0.5) AS phoneVerified,

    NOW() - (RANDOM() * INTERVAL '100 days') AS lastLogin,
    NOW() AS lastUpdate,

    -- status / pref
    'active' AS status,
    'default' AS pref,

    -- ranking & adminScore
    (RANDOM() * 5)::NUMERIC AS rs,
    (RANDOM() * 5)::NUMERIC AS adminScore,
    '{}'::jsonb AS adminScoreInfo,

    -- pro column random enum
    (ARRAY['vip1','vip2','vip3',''])[FLOOR(RANDOM()*4)+1] AS pro,

    -- misc text fields
    'tutor' AS type,
    'en' AS lang,

    1000 + generate_series AS userNo,
    'provider' AS providerId,
    NOW() - (RANDOM() * INTERVAL '365 days') AS createdAt,

    'https://example.com/img/' || generate_series AS img,
    (RANDOM() * 5)::NUMERIC AS rate,
    (RANDOM() * 20)::DOUBLE PRECISION AS rateTimes,
    (RANDOM() * 5)::NUMERIC AS rateFinal,

    '{}'::jsonb AS badge,

    -- fee ranges
    (RANDOM() * 100)::NUMERIC AS fee,
    (RANDOM() * 200)::NUMERIC AS feeMax,
    'hourly' AS feeType,
    'MYR' AS currency,

    NOW() - ((18 + RANDOM()*30) || ' years')::interval AS age,
    (ARRAY['male','female'])[FLOOR(RANDOM()*2)+1] AS gender,

    'Address ' || generate_series AS address,
    'Area ' || generate_series AS area,
    'Place ' || generate_series AS place,

    'Qualification text' AS qua,
    (FLOOR(RANDOM()*10)+1)::TEXT AS yrExp,
    'Short intro text' AS intro,
    'Teaching approach text' AS approach,

    -- RANDOM AREA assignment
    (ARRAY['area_1']) AS areas,

    -- RANDOM subjects mix
    (ARRAY[
        (ARRAY['math','english', 'history', 'chemistry', 'biology', 'physics', 'malay', 'chinese', 'phonics', 'account'])[FLOOR(RANDOM()*10)+1],
        (ARRAY['math','english', 'history', 'chemistry', 'biology', 'physics', 'malay', 'chinese', 'phonics', 'account'])[FLOOR(RANDOM()*10)+1],
        (ARRAY['math','english', 'history', 'chemistry', 'biology', 'physics', 'malay', 'chinese', 'phonics', 'account'])[FLOOR(RANDOM()*10)+1],
        (ARRAY['math','english', 'history', 'chemistry', 'biology', 'physics', 'malay', 'chinese', 'phonics', 'account'])[FLOOR(RANDOM()*10)+1]
    ]) AS subjects,

    -- modes
    ARRAY['online','physical'] AS modes,

    '{}'::jsonb AS timeslot,

    'none' AS glplus,
    NOW() - (RANDOM() * INTERVAL '30 days') AS lastOnline,

    '{}'::jsonb AS summary,
    '{}'::jsonb AS policy,

    gen_random_uuid(),
    gen_random_uuid(),
    gen_random_uuid()

FROM generate_series(1, 20);
