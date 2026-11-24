-- Run AFTER the initial migration, as postgres in the NEW project's SQL Editor.
-- Every fixture is rolled back. This never sends notifications or emails.
begin;

insert into auth.users(id, email, raw_user_meta_data) values
  ('11111111-1111-4111-8111-111111111111', 'cihuy-schema-a@example.invalid', '{"full_name":"Schema test A"}'),
  ('22222222-2222-4222-8222-222222222222', 'cihuy-schema-b@example.invalid', '{}');
insert into public.consumption_habits(id, user_id, kind) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'cigarette'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '22222222-2222-4222-8222-222222222222', 'vape');

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);

do $$
begin
  if (select count(*) from public.profiles) <> 1
    or (select count(*) from public.notification_preferences) <> 1
    or (select count(*) from public.consumption_habits) <> 1 then
    raise exception 'FAIL: account isolation or signup provisioning';
  end if;
  if has_table_privilege('anon', 'public.consumption_records', 'SELECT')
    or has_table_privilege('authenticated', 'public.notification_devices', 'SELECT')
    or has_table_privilege('authenticated', 'public.notification_deliveries', 'INSERT') then
    raise exception 'FAIL: excessive client privileges';
  end if;
  begin
    insert into public.craving_records(user_id, habit_id, occurred_at)
    values ('22222222-2222-4222-8222-222222222222', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', now());
    raise exception 'FAIL: account spoof accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.consumption_records(habit_id, consumed_at, amount)
    values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', now(), 1);
    raise exception 'FAIL: another account habit accepted';
  exception when foreign_key_violation then null;
  end;
  begin
    update public.consumption_habits set kind = 'vape'
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    raise exception 'FAIL: existing habit unit could be changed';
  exception when insufficient_privilege then null;
  end;
  update public.profiles set display_name = 'Updated test name'
  where id = '11111111-1111-4111-8111-111111111111';
  update public.notification_preferences set timezone = 'Asia/Jakarta';
  begin
    update public.notification_preferences set timezone = 'Not/AZone';
    raise exception 'FAIL: invalid timezone accepted';
  exception when check_violation then null;
  end;
end;
$$;

insert into public.daily_targets(habit_id, daily_limit, starts_on, ends_on) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 5, '2026-09-01', '2026-09-08'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 2, '2026-09-08', null);
do $$
begin
  begin
    insert into public.daily_targets(habit_id, daily_limit, starts_on, ends_on)
    values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 3, '2026-09-07', '2026-09-09');
    raise exception 'FAIL: overlapping targets accepted';
  exception when exclusion_violation then null;
  end;
  begin
    insert into public.consumption_records(habit_id, consumed_at, amount)
    values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', now(), 0);
    raise exception 'FAIL: zero consumption accepted';
  exception when check_violation then null;
  end;
end;
$$;

insert into public.consumption_records(id, habit_id, consumed_at, amount) values
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '2026-09-07T09:00:00+08:00', 2),
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '2026-09-07T12:00:00+08:00', 3);
do $$
declare total bigint; historical_limit integer;
begin
  select daily_limit into strict historical_limit from public.daily_targets
  where habit_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
    and starts_on <= date '2026-09-07' and (ends_on is null or date '2026-09-07' < ends_on);
  select sum(amount) into total from public.consumption_records
  where habit_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
    and (consumed_at at time zone 'Asia/Makassar')::date = date '2026-09-07';
  if historical_limit <> 5 or total <> 5 or total > historical_limit then
    raise exception 'FAIL: historical limit / 5 of 5';
  end if;
  update public.consumption_records set amount = 4 where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  select sum(amount) into total from public.consumption_records
  where habit_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  if total <> 6 or not (total > historical_limit) then raise exception 'FAIL: 6 of 5'; end if;
  update public.consumption_records set amount = 3 where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  select sum(amount) into total from public.consumption_records
  where habit_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  if total <> 5 or total > historical_limit then raise exception 'FAIL: correction 6 to 5'; end if;
end;
$$;

reset role;
insert into public.notification_deliveries(user_id, device_id, kind, local_date) values
  ('11111111-1111-4111-8111-111111111111', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'progress', '2026-09-07');
do $$
begin
  begin
    insert into public.notification_deliveries(user_id, device_id, kind, local_date) values
      ('11111111-1111-4111-8111-111111111111', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'progress', '2026-09-07');
    raise exception 'FAIL: duplicate delivery claim accepted';
  exception when unique_violation then null;
  end;
end;
$$;

rollback;
select 'PASS: isolation, privileges, ownership, targets, correction, validation and duplicate claims. Fixtures rolled back.' as result;
