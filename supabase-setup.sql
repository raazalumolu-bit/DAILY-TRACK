-- Run this once in Supabase: SQL Editor > New query > paste > Run
-- BEFORE running, replace CHANGE_THIS_SECRET (2 places) with your own secret word.
-- Use the SAME secret word in the phone app and on the dashboard page.

create table if not exists daily_reports (
  day date primary key,
  report jsonb not null,
  updated_at timestamptz not null default now()
);

-- lock the table: nobody can read or write it directly
alter table daily_reports enable row level security;

create or replace function put_report(p_key text, p_day date, p_report jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_key <> 'CHANGE_THIS_SECRET' then
    raise exception 'wrong key';
  end if;
  insert into daily_reports(day, report, updated_at)
  values (p_day, p_report, now())
  on conflict (day) do update set report = excluded.report, updated_at = now();
end;
$$;

create or replace function get_reports(p_key text, p_from date, p_to date)
returns setof daily_reports
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_key <> 'CHANGE_THIS_SECRET' then
    raise exception 'wrong key';
  end if;
  return query select * from daily_reports where day between p_from and p_to order by day desc;
end;
$$;

grant execute on function put_report(text, date, jsonb) to anon;
grant execute on function get_reports(text, date, date) to anon;
