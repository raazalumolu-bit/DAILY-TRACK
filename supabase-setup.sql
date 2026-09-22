-- Day Log Supabase setup (multi-device)
-- Supabase SQL Editor → New query → paste all → Run
-- Replace YOUR_SECRET_WORD (3 places) with a word you choose.
-- Use the SAME secret word on both phones and on the web dashboard.

-- ── 1. tables ─────────────────────────────────────────────────────────────────
create table if not exists daily_reports (
  device_id text  not null,
  day       date  not null,
  report    jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (device_id, day)
);

create table if not exists live_location (
  device_id   text  primary key,
  device_name text,
  lat         double precision,
  lng         double precision,
  acc         double precision,
  updated_at  timestamptz not null default now()
);

alter table daily_reports enable row level security;
alter table live_location  enable row level security;

-- ── 2. write a report ─────────────────────────────────────────────────────────
create or replace function put_report(
  p_key text, p_device_id text, p_device_name text,
  p_day date, p_report jsonb)
returns void language plpgsql security definer set search_path=public as $$
begin
  if p_key <> 'YOUR_SECRET_WORD' then raise exception 'wrong key'; end if;
  insert into daily_reports(device_id,day,report,updated_at)
  values(p_device_id,p_day,p_report,now())
  on conflict(device_id,day) do update
    set report=excluded.report, updated_at=now();
end;$$;

-- ── 3. read reports for one device ────────────────────────────────────────────
create or replace function get_reports(
  p_key text, p_device_id text, p_from date, p_to date)
returns setof daily_reports language plpgsql security definer set search_path=public as $$
begin
  if p_key <> 'YOUR_SECRET_WORD' then raise exception 'wrong key'; end if;
  return query
    select * from daily_reports
    where device_id=p_device_id and day between p_from and p_to
    order by day desc;
end;$$;

-- ── 4. list all devices ───────────────────────────────────────────────────────
create or replace function get_devices(p_key text)
returns table(device_id text, device_name text, last_seen timestamptz, last_day date)
language plpgsql security definer set search_path=public as $$
begin
  if p_key <> 'YOUR_SECRET_WORD' then raise exception 'wrong key'; end if;
  return query
    select l.device_id, l.device_name, l.updated_at, r.day
    from live_location l
    left join (
      select device_id, max(day) as day from daily_reports group by device_id
    ) r on r.device_id=l.device_id
    order by l.updated_at desc;
end;$$;

-- ── 5. live location ──────────────────────────────────────────────────────────
create or replace function update_live(
  p_key text, p_device_id text, p_device_name text,
  p_lat double precision, p_lng double precision, p_acc double precision)
returns void language plpgsql security definer set search_path=public as $$
begin
  if p_key <> 'YOUR_SECRET_WORD' then raise exception 'wrong key'; end if;
  insert into live_location(device_id,device_name,lat,lng,acc,updated_at)
  values(p_device_id,p_device_name,p_lat,p_lng,p_acc,now())
  on conflict(device_id) do update
    set device_name=excluded.device_name, lat=excluded.lat, lng=excluded.lng,
        acc=excluded.acc, updated_at=now();
end;$$;

-- ── 6. grant to anon ──────────────────────────────────────────────────────────
grant execute on function put_report(text,text,text,date,jsonb)        to anon;
grant execute on function get_reports(text,text,date,date)             to anon;
grant execute on function get_devices(text)                            to anon;
grant execute on function update_live(text,text,text,double precision,double precision,double precision) to anon;
