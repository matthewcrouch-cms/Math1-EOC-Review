-- =====================================================================
-- Math 1 EOC Review · Supabase schema
-- Run this whole file once in Supabase → SQL Editor → New query → Run.
-- Then run seed.sql (questions + answer keys; kept out of the public repo).
-- Safe to re-run: it rebuilds functions but never deletes student work.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------------- TABLES ----------------
create table if not exists settings (
  id int primary key default 1 check (id = 1),
  scoring jsonb not null,
  updated_at timestamptz not null default now()
);
insert into settings (id, scoring) values (1, '{
  "max_attempts": 5, "wrong_pct": 5, "hint_costs": [5, 10, 20], "floor_pct": 50,
  "late_pct_per_day": 2, "draft": true
}'::jsonb) on conflict (id) do nothing;

create table if not exists teachers (
  id serial primary key,
  name text not null,
  email text not null,
  pw_hash text not null,
  is_admin boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index if not exists teachers_email_uq on teachers (lower(email));

create table if not exists teacher_sessions (
  token text primary key,
  teacher_id int not null references teachers(id) on delete cascade,
  expires_at timestamptz not null
);

create table if not exists classes (
  id serial primary key,
  teacher_id int not null references teachers(id) on delete cascade,
  name text not null,
  active boolean not null default true
);

create table if not exists students (
  id serial primary key,
  teacher_id int not null references teachers(id) on delete cascade,
  class_id int references classes(id) on delete set null,
  first text not null,
  last text not null,
  pin text not null,
  active boolean not null default true,
  is_test boolean not null default false,
  fails int not null default 0,
  locked_until timestamptz
);

create table if not exists student_sessions (
  token text primary key,
  student_id int not null references students(id) on delete cascade,
  expires_at timestamptz not null
);

create table if not exists hw_sets (
  id int primary key,
  title text not null,
  calc boolean not null
);

create table if not exists problems (
  id text primary key,
  set_id int not null references hw_sets(id) on delete cascade,
  n int not null,
  title text,
  stem text not null,
  topic text,
  std text,
  active boolean not null default true
);

create table if not exists parts (
  id text primary key,
  problem_id text not null references problems(id) on delete cascade,
  ord int not null,
  label text not null default '',
  prompt text not null default '',
  kind text not null,
  spec jsonb not null,
  answer jsonb not null,
  answer_display text not null default '',
  hints jsonb not null default '[]',
  explanation text not null default ''
);

-- An assignment = one night of homework = one or more HW sets.
create table if not exists assignments (
  id text primary key,
  sort int not null,
  title text not null,
  set_ids int[] not null,
  opens timestamptz,   -- department default dates; each teacher can override
  due timestamptz,
  closes timestamptz
);

create table if not exists schedules (
  teacher_id int not null references teachers(id) on delete cascade,
  assignment_id text not null references assignments(id) on delete cascade,
  opens timestamptz not null,
  due timestamptz not null,
  closes timestamptz not null,
  primary key (teacher_id, assignment_id)
);

create table if not exists ext_dates (
  student_id int not null references students(id) on delete cascade,
  assignment_id text not null references assignments(id) on delete cascade,
  due timestamptz not null,
  closes timestamptz not null,
  primary key (student_id, assignment_id)
);

create table if not exists no_school (
  day date primary key,
  note text
);

create table if not exists states (
  student_id int not null references students(id) on delete cascade,
  part_id text not null references parts(id) on delete cascade,
  wrong int not null default 0,
  hint_tier int not null default 0,
  done boolean not null default false,
  correct boolean not null default false,
  late_days int not null default 0,
  last_answer jsonb,
  updated_at timestamptz not null default now(),
  finished_at timestamptz,
  primary key (student_id, part_id)
);

-- Lock every table: the browser can only use the functions below.
do $$ declare t text; begin
  foreach t in array array['settings','teachers','teacher_sessions','classes','students','student_sessions','hw_sets',
                           'problems','parts','assignments','schedules','ext_dates','no_school','states'] loop
    execute format('alter table %I enable row level security', t);
    execute format('revoke all on %I from anon, authenticated', t);
  end loop;
end $$;

-- ---------------- HELPERS ----------------
create or replace function _err(msg text) returns void language plpgsql as $$
begin raise exception using message = msg; end $$;

create or replace function _token() returns text language sql as $$
  select encode(extensions.gen_random_bytes(24), 'hex') $$;

create or replace function _scoring() returns jsonb language sql stable as $$
  select scoring from settings where id = 1 $$;

create or replace function _student(p_token text) returns students
language plpgsql stable security definer set search_path = public as $$
declare s students;
begin
  select st.* into s from student_sessions ss join students st on st.id = ss.student_id
   where ss.token = p_token and ss.expires_at > now() and st.active;
  if s.id is null then perform _err('SESSION_EXPIRED'); end if;
  return s;
end $$;

create or replace function _teacher(p_token text) returns teachers
language plpgsql stable security definer set search_path = public as $$
declare t teachers;
begin
  select te.* into t from teacher_sessions ts join teachers te on te.id = ts.teacher_id
   where ts.token = p_token and ts.expires_at > now() and te.active;
  if t.id is null then perform _err('SESSION_EXPIRED'); end if;
  return t;
end $$;

create or replace function _admin(p_token text) returns teachers
language plpgsql stable security definer set search_path = public as $$
declare t teachers := _teacher(p_token);
begin
  if not t.is_admin then perform _err('Only the platform admin can do that.'); end if;
  return t;
end $$;

-- School days strictly after the due date, up to and including the finish date (Eastern time).
create or replace function _school_days_late(p_due timestamptz, p_at timestamptz) returns int
language sql stable set search_path = public as $$
  select case when p_at <= p_due then 0 else (
    select count(*)::int from generate_series((p_due at time zone 'America/New_York')::date + 1,
                                              (p_at at time zone 'America/New_York')::date, interval '1 day') d
     where extract(isodow from d) < 6 and d::date not in (select day from no_school)) end $$;

-- Effective dates for a student (extension > teacher schedule > department default)
create or replace function _dates(p_student students, p_assignment text,
  out opens timestamptz, out due timestamptz, out closes timestamptz)
language sql stable security definer set search_path = public as $$
  select coalesce(sc.opens, a.opens),
         coalesce(e.due, sc.due, a.due),
         coalesce(e.closes, sc.closes, a.closes)
    from assignments a
    left join schedules sc on sc.assignment_id = a.id and sc.teacher_id = p_student.teacher_id
    left join ext_dates e on e.assignment_id = a.id and e.student_id = p_student.id
   where a.id = p_assignment $$;

create or replace function _status(p_student students, p_assignment text) returns text
language plpgsql stable security definer set search_path = public as $$
declare d record;
begin
  if p_student.is_test then return 'open'; end if;
  select * into d from _dates(p_student, p_assignment);
  if d.opens is null or now() < d.opens then return 'upcoming'; end if;
  if now() <= d.due then return 'open'; end if;
  if now() <= d.closes then return 'late'; end if;
  return 'closed';
end $$;

-- Points for each active part of an assignment: 100 split evenly over active problems, then over parts.
create or replace function _part_points(p_assignment text)
returns table (part_id text, problem_id text, set_id int, points numeric)
language sql stable security definer set search_path = public as $$
  with a as (select set_ids from assignments where id = p_assignment),
  pr as (select p.id, p.set_id from problems p, a where p.active and p.set_id = any(a.set_ids)),
  n as (select count(*) c from pr)
  select pa.id, pr.id, pr.set_id,
         100.0 / nullif((select c from n), 0) / count(*) over (partition by pr.id)
    from pr join parts pa on pa.problem_id = pr.id $$;

-- Percent earned on a finished part, using the current department scoring settings.
create or replace function _pct(p_correct boolean, p_done boolean, p_wrong int, p_hint int, p_late int) returns numeric
language plpgsql stable set search_path = public as $$
declare s jsonb := _scoring(); hc numeric := 0; pct numeric;
begin
  if not p_done or not p_correct then return 0; end if;
  if p_hint > 0 then hc := coalesce((s->'hint_costs'->>(p_hint - 1))::numeric, 0); end if;
  pct := greatest((s->>'floor_pct')::numeric, 100 - hc - p_wrong * (s->>'wrong_pct')::numeric);
  pct := pct - p_late * (s->>'late_pct_per_day')::numeric;
  return greatest(pct, 0);
end $$;

-- ---------------- GRADING ----------------
-- Returns {"ok": true|false} or {"invalid": "message"}
create or replace function _grade(p_kind text, p_spec jsonb, p_key jsonb, p_given jsonb) returns jsonb
language plpgsql immutable as $$
declare v numeric; i int; n int; arr jsonb; ok boolean; k text; acc jsonb;
begin
  if p_given is null or p_given = 'null'::jsonb then return '{"invalid":"Enter an answer first."}'; end if;
  if p_kind = 'mc' then
    if jsonb_typeof(p_given) <> 'string' or p_given #>> '{}' = '' then return '{"invalid":"Choose an answer first."}'; end if;
    return jsonb_build_object('ok', p_key->'accept' ? (p_given #>> '{}'));
  elsif p_kind = 'multi' then
    if jsonb_typeof(p_given) <> 'array' or jsonb_array_length(p_given) = 0 then return '{"invalid":"Select at least one answer."}'; end if;
    if p_spec ? 'count' and jsonb_typeof(p_spec->'count') = 'number' and jsonb_array_length(p_given) <> (p_spec->>'count')::int then
      return jsonb_build_object('invalid', format('Select exactly %s answers.', p_spec->>'count'));
    end if;
    select coalesce(jsonb_agg(x order by x), '[]') into arr from (select distinct jsonb_array_elements_text(p_given) x) q;
    return jsonb_build_object('ok', arr = (select coalesce(jsonb_agg(x order by x), '[]') from jsonb_array_elements_text(p_key->'set') x));
  elsif p_kind = 'num' then
    if jsonb_typeof(p_given->'v') <> 'number' then return '{"invalid":"That doesn''t look like a number. Check what you typed."}'; end if;
    return jsonb_build_object('ok', abs((p_given->>'v')::numeric - (p_key->>'v')::numeric) <= (p_key->>'tol')::numeric + 1e-9);
  elsif p_kind = 'nums' then
    n := jsonb_array_length(p_key->'vs');
    if jsonb_typeof(p_given->'v') <> 'array' or jsonb_array_length(p_given->'v') <> n
       or exists (select 1 from jsonb_array_elements(p_given->'v') e where jsonb_typeof(e) <> 'number') then
      return jsonb_build_object('invalid', format('Enter all %s answers as numbers.', n));
    end if;
    select jsonb_agg(e order by e::numeric) into arr from jsonb_array_elements_text(p_given->'v') e;
    ok := true;
    for i in 0 .. n - 1 loop
      if abs((arr->>i)::numeric - (p_key->'vs'->>i)::numeric) > (p_key->>'tol')::numeric + 1e-9 then ok := false; end if;
    end loop;
    return jsonb_build_object('ok', ok);
  elsif p_kind = 'expr' then
    n := jsonb_array_length(p_key->'vals');
    if jsonb_typeof(p_given->'v') <> 'array' or jsonb_array_length(p_given->'v') <> n
       or exists (select 1 from jsonb_array_elements(p_given->'v') e where jsonb_typeof(e) <> 'number') then
      return '{"invalid":"We couldn''t read that expression. Check your parentheses and use ^ for exponents."}';
    end if;
    ok := true;
    for i in 0 .. n - 1 loop
      v := (p_key->'vals'->>i)::numeric;
      if abs((p_given->'v'->>i)::numeric - v) > (p_key->>'rel')::numeric * greatest(1, abs(v)) then ok := false; end if;
    end loop;
    return jsonb_build_object('ok', ok);
  elsif p_kind = 'fill' then
    for k in select jsonb_array_elements_text(p_spec->'slots') loop
      if coalesce(p_given->>k, '') = '' then return '{"invalid":"Fill every box before you check."}'; end if;
    end loop;
    for acc in select jsonb_array_elements(p_key->'accept') loop
      ok := true;
      for k in select jsonb_object_keys(acc) loop
        if p_given->>k is distinct from acc->>k then ok := false; end if;
      end loop;
      if ok then return '{"ok":true}'; end if;
    end loop;
    return '{"ok":false}';
  elsif p_kind = 'coord' then
    n := jsonb_array_length(p_key->'pts');
    if jsonb_typeof(p_given) <> 'array' or jsonb_array_length(p_given) <> n
       or exists (select 1 from jsonb_array_elements(p_given) pt, jsonb_array_elements(pt) c where jsonb_typeof(c) <> 'number') then
      return '{"invalid":"Enter both coordinates as numbers."}';
    end if;
    ok := true;
    for i in 0 .. n - 1 loop
      if abs((p_given->i->>0)::numeric - (p_key->'pts'->i->>0)::numeric) > (p_key->>'tol')::numeric + 1e-9
         or abs((p_given->i->>1)::numeric - (p_key->'pts'->i->>1)::numeric) > (p_key->>'tol')::numeric + 1e-9 then ok := false; end if;
    end loop;
    return jsonb_build_object('ok', ok);
  end if;
  return '{"invalid":"Unknown question type."}';
end $$;

-- The JSON a student sees for one part (answers only once finished or closed).
create or replace function _part_json(p_student students, p_part parts, p_points numeric, p_closed boolean) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare st states; s jsonb := _scoring(); nh int := jsonb_array_length(p_part.hints); show boolean;
begin
  select * into st from states where student_id = p_student.id and part_id = p_part.id;
  show := coalesce(st.done, false) or p_closed;
  return jsonb_build_object(
    'id', p_part.id, 'label', p_part.label, 'prompt', p_part.prompt, 'kind', p_part.kind, 'spec', p_part.spec,
    'points', p_points,
    'wrong', coalesce(st.wrong, 0), 'hint_tier', coalesce(st.hint_tier, 0),
    'done', coalesce(st.done, false), 'correct', coalesce(st.correct, false), 'late_days', coalesce(st.late_days, 0),
    'score', p_points * _pct(coalesce(st.correct, false), coalesce(st.done, false), coalesce(st.wrong, 0), coalesce(st.hint_tier, 0), coalesce(st.late_days, 0)) / 100,
    'last_answer', st.last_answer,
    'max_attempts', (s->>'max_attempts')::int,
    'hint_count', least(nh, jsonb_array_length(s->'hint_costs')),
    'hint_costs', (select coalesce(jsonb_agg(x), '[]') from (select x from jsonb_array_elements(s->'hint_costs') with ordinality h(x, i) where i <= nh) q),
    'hints', (select coalesce(jsonb_agg(h order by i), '[]') from jsonb_array_elements(p_part.hints) with ordinality t(h, i) where i <= coalesce(st.hint_tier, 0) or show),
    'explanation', case when show then p_part.explanation end,
    'answer_display', case when show then p_part.answer_display end);
end $$;

-- ---------------- STUDENT API ----------------
create or replace function hw_teachers() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name) order by t.name), '[]')
    from teachers t where t.active and exists (select 1 from classes c where c.teacher_id = t.id and c.active) $$;

create or replace function hw_classes(p_teacher int) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name) order by c.name), '[]')
    from classes c where c.teacher_id = p_teacher and c.active $$;

create or replace function hw_students(p_class int) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'name', s.first || ' ' || s.last) order by s.first, s.last), '[]')
    from students s where s.class_id = p_class and s.active and not s.is_test $$;

create or replace function hw_login(p_student int, p_pin text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare s students; tok text;
begin
  select * into s from students where id = p_student and active and not is_test;
  if s.id is null then perform _err('Student not found.'); end if;
  if s.locked_until is not null and s.locked_until > now() then
    perform _err('Too many wrong PINs. Wait a few minutes or ask your teacher to unlock you.');
  end if;
  if s.pin <> p_pin then
    update students set fails = fails + 1,
      locked_until = case when fails + 1 >= 5 then now() + interval '5 minutes' else null end where id = s.id;
    perform _err('That PIN is not right. Try again.');
  end if;
  update students set fails = 0, locked_until = null where id = s.id;
  tok := _token();
  insert into student_sessions values (tok, s.id, now() + interval '30 days');
  return jsonb_build_object('token', tok);
end $$;

create or replace function hw_logout(p_token text) returns void
language sql volatile security definer set search_path = public as $$
  delete from student_sessions where token = p_token $$;

create or replace function hw_my_assignments(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s students := _student(p_token); out jsonb := '[]'; a assignments; d record; pts record;
  sc numeric; done int; total int;
begin
  for a in select * from assignments order by sort loop
    select * into d from _dates(s, a.id);
    with x as (
      select pp.problem_id, sum(pp.points * coalesce(_pct(st.correct, st.done, st.wrong, st.hint_tier, st.late_days), 0) / 100) psc,
             bool_and(coalesce(st.done, false)) pdone
        from _part_points(a.id) pp left join states st on st.part_id = pp.part_id and st.student_id = s.id
       group by pp.problem_id)
    select coalesce(sum(psc), 0), count(*) filter (where pdone), count(*) into sc, done, total from x;
    out := out || jsonb_build_object('id', a.id, 'title', a.title, 'sort', a.sort, 'status', _status(s, a.id),
      'opens', d.opens, 'due', d.due, 'closes', d.closes, 'score', round(sc, 2), 'done', done, 'parts', total,
      'sets', (select jsonb_agg(jsonb_build_object('id', h.id, 'title', h.title, 'calc', h.calc) order by array_position(a.set_ids, h.id))
                 from hw_sets h where h.id = any(a.set_ids)));
  end loop;
  return jsonb_build_object('name', s.first || ' ' || s.last, 'is_test', s.is_test,
    'teacher', (select name from teachers where id = s.teacher_id), 'scoring', _scoring(), 'assignments', out);
end $$;

create or replace function hw_assignment(p_token text, p_assignment text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s students := _student(p_token); a assignments; st text; d record; closed boolean;
  sections jsonb := '[]'; sid int; probs jsonb; total numeric := 0;
begin
  select * into a from assignments where id = p_assignment;
  if a.id is null then perform _err('Assignment not found.'); end if;
  st := _status(s, a.id);
  if st = 'upcoming' then perform _err('This homework is not open yet.'); end if;
  closed := st = 'closed';
  select * into d from _dates(s, a.id);
  foreach sid in array a.set_ids loop
    select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'n', p.n, 'title', p.title, 'stem', p.stem, 'topic', p.topic, 'std', p.std,
             'parts', (select jsonb_agg(_part_json(s, pa, pp.points, closed) order by pa.ord)
                         from parts pa join _part_points(a.id) pp on pp.part_id = pa.id where pa.problem_id = p.id))
             order by p.n), '[]')
      into probs from problems p where p.set_id = sid and p.active;
    sections := sections || jsonb_build_object('set', (select jsonb_build_object('id', id, 'title', title, 'calc', calc) from hw_sets where id = sid), 'problems', probs);
  end loop;
  select coalesce(sum(pp.points * _pct(x.correct, x.done, x.wrong, x.hint_tier, x.late_days) / 100), 0) into total
    from _part_points(a.id) pp join states x on x.part_id = pp.part_id and x.student_id = s.id;
  return jsonb_build_object('id', a.id, 'title', a.title, 'status', st, 'opens', d.opens, 'due', d.due, 'closes', d.closes,
    'score', round(total, 2), 'scoring', _scoring(), 'sections', sections, 'is_test', s.is_test);
end $$;

create or replace function _part_context(s students, p_part text, out pa parts, out aid text, out pts numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  select * into pa from parts where id = p_part;
  if pa.id is null then perform _err('Question not found.'); end if;
  -- the assignment this student is working in that contains the part's set
  select a.id into aid from assignments a join problems p on p.set_id = any(a.set_ids)
   where p.id = pa.problem_id and p.active order by a.sort limit 1;
  if aid is null then perform _err('This question has been turned off by your teacher.'); end if;
  select pp.points into pts from _part_points(aid) pp where pp.part_id = pa.id;
end $$;

create or replace function hw_submit(p_token text, p_part text, p_answer jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare s students := _student(p_token); c record; st states; status text; g jsonb; d record; sc jsonb := _scoring();
  maxa int := (sc->>'max_attempts')::int;
begin
  select * into c from _part_context(s, p_part);
  status := _status(s, c.aid);
  if status in ('upcoming', 'closed') then perform _err('This homework is ' || case when status = 'closed' then 'closed.' else 'not open yet.' end); end if;
  insert into states (student_id, part_id) values (s.id, p_part) on conflict do nothing;
  select * into st from states where student_id = s.id and part_id = p_part for update;
  if st.done then perform _err('You already finished this question.'); end if;
  g := _grade((c.pa).kind, (c.pa).spec, (c.pa).answer, p_answer);
  if g ? 'invalid' then
    update states set last_answer = p_answer, updated_at = now() where student_id = s.id and part_id = p_part;
    return jsonb_build_object('result', jsonb_build_object('invalid', true, 'msg', g->>'invalid'),
      'part', _part_json(s, (select pa from parts pa where id = p_part), c.pts, false));
  end if;
  select * into d from _dates(s, c.aid);
  if (g->>'ok')::boolean then
    update states set done = true, correct = true, last_answer = p_answer, finished_at = now(), updated_at = now(),
      late_days = case when s.is_test then 0 else _school_days_late(d.due, now()) end
     where student_id = s.id and part_id = p_part;
  else
    update states set wrong = wrong + 1, last_answer = p_answer, updated_at = now(),
      done = (wrong + 1 >= maxa), finished_at = case when wrong + 1 >= maxa then now() end
     where student_id = s.id and part_id = p_part;
  end if;
  return jsonb_build_object('result', jsonb_build_object('correct', (g->>'ok')::boolean),
    'part', _part_json(s, (select pa from parts pa where id = p_part), c.pts, false));
end $$;

create or replace function hw_hint(p_token text, p_part text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare s students := _student(p_token); c record; st states; status text; nh int; sc jsonb := _scoring();
begin
  select * into c from _part_context(s, p_part);
  status := _status(s, c.aid);
  if status in ('upcoming', 'closed') then perform _err('This homework is not open.'); end if;
  insert into states (student_id, part_id) values (s.id, p_part) on conflict do nothing;
  select * into st from states where student_id = s.id and part_id = p_part for update;
  nh := least(jsonb_array_length((c.pa).hints), jsonb_array_length(sc->'hint_costs'));
  if st.done then perform _err('You already finished this question.'); end if;
  if st.hint_tier >= nh then perform _err('No more hints for this question.'); end if;
  update states set hint_tier = hint_tier + 1, updated_at = now() where student_id = s.id and part_id = p_part;
  return jsonb_build_object('part', _part_json(s, (select pa from parts pa where id = p_part), c.pts, false));
end $$;

-- ---------------- TEACHER API ----------------
create or replace function t_login(p_email text, p_password text) returns jsonb
language plpgsql volatile security definer set search_path = public, extensions as $$
declare t teachers; tok text;
begin
  select * into t from teachers where lower(email) = lower(trim(p_email)) and active;
  if t.id is null or t.pw_hash <> extensions.crypt(p_password, t.pw_hash) then
    perform pg_sleep(0.6);
    perform _err('Email or password is not right.');
  end if;
  delete from teacher_sessions where expires_at < now();
  tok := _token();
  insert into teacher_sessions values (tok, t.id, now() + interval '14 days');
  -- first login: copy the department default dates into this teacher's schedule
  insert into schedules (teacher_id, assignment_id, opens, due, closes)
    select t.id, a.id, a.opens, a.due, a.closes from assignments a
     where a.opens is not null and a.due is not null and a.closes is not null
    on conflict do nothing;
  return jsonb_build_object('token', tok);
end $$;

create or replace function t_logout(p_token text) returns void
language sql volatile security definer set search_path = public as $$
  delete from teacher_sessions where token = p_token $$;

create or replace function t_change_password(p_token text, p_old text, p_new text) returns void
language plpgsql volatile security definer set search_path = public, extensions as $$
declare t teachers := _teacher(p_token);
begin
  if t.pw_hash <> extensions.crypt(p_old, t.pw_hash) then perform _err('Your current password is not right.'); end if;
  if length(p_new) < 8 then perform _err('Use at least 8 characters.'); end if;
  update teachers set pw_hash = extensions.crypt(p_new, extensions.gen_salt('bf')) where id = t.id;
end $$;

-- Everything the dashboard needs, for this teacher only.
create or replace function t_data(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare t teachers := _teacher(p_token);
begin
  return jsonb_build_object(
    'me', jsonb_build_object('id', t.id, 'name', t.name, 'email', t.email, 'is_admin', t.is_admin),
    'scoring', _scoring(),
    'classes', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'active', active) order by name), '[]') from classes where teacher_id = t.id),
    'students', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'class_id', class_id, 'first', first, 'last', last, 'pin', pin,
                    'active', active, 'locked', locked_until > now()) order by last, first), '[]') from students where teacher_id = t.id and not is_test),
    'sets', (select jsonb_agg(jsonb_build_object('id', id, 'title', title, 'calc', calc) order by id) from hw_sets),
    'assignments', (select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'title', a.title, 'sort', a.sort, 'set_ids', a.set_ids,
                       'opens', coalesce(sc.opens, a.opens), 'due', coalesce(sc.due, a.due), 'closes', coalesce(sc.closes, a.closes),
                       'default', jsonb_build_object('opens', a.opens, 'due', a.due, 'closes', a.closes),
                       'parts', (select jsonb_agg(jsonb_build_object('id', pp.part_id, 'problem', pp.problem_id, 'set', pp.set_id, 'points', pp.points,
                                    'label', pa.label, 'n', p.n, 'topic', p.topic, 'std', p.std) order by array_position(a.set_ids, p.set_id), p.n, pa.ord)
                                  from _part_points(a.id) pp join parts pa on pa.id = pp.part_id join problems p on p.id = pp.problem_id))
                     order by a.sort), '[]')
                    from assignments a left join schedules sc on sc.assignment_id = a.id and sc.teacher_id = t.id),
    'states', (select coalesce(jsonb_agg(jsonb_build_object('s', x.student_id, 'p', x.part_id, 'wrong', x.wrong, 'hint', x.hint_tier,
                  'done', x.done, 'correct', x.correct, 'late', x.late_days, 'at', x.finished_at,
                  'pct', _pct(x.correct, x.done, x.wrong, x.hint_tier, x.late_days))), '[]')
                 from states x join students s on s.id = x.student_id where s.teacher_id = t.id and not s.is_test),
    'extensions', (select coalesce(jsonb_agg(jsonb_build_object('s', e.student_id, 'a', e.assignment_id, 'due', e.due, 'closes', e.closes)), '[]')
                     from ext_dates e join students s on s.id = e.student_id where s.teacher_id = t.id),
    'no_school', (select coalesce(jsonb_agg(jsonb_build_object('day', day, 'note', note) order by day), '[]') from no_school));
end $$;

create or replace function t_class(p_token text, p_action text, p_class int, p_name text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare t teachers := _teacher(p_token);
begin
  if p_action = 'add' then
    if coalesce(trim(p_name), '') = '' then perform _err('Give the class a name, like "Block 2".'); end if;
    insert into classes (teacher_id, name) values (t.id, trim(p_name));
    return;
  end if;
  if not exists (select 1 from classes where id = p_class and teacher_id = t.id) then perform _err('Class not found.'); end if;
  if p_action = 'rename' then update classes set name = trim(p_name) where id = p_class;
  elsif p_action = 'hide' then update classes set active = false where id = p_class;
  elsif p_action = 'show' then update classes set active = true where id = p_class;
  else perform _err('Unknown action.'); end if;
end $$;

create or replace function t_add_students(p_token text, p_class int, p_names jsonb) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare t teachers := _teacher(p_token); n jsonb; added int := 0;
begin
  if not exists (select 1 from classes where id = p_class and teacher_id = t.id) then perform _err('Pick one of your classes first.'); end if;
  for n in select * from jsonb_array_elements(p_names) loop
    if not exists (select 1 from students where teacher_id = t.id and class_id = p_class and not is_test
                    and lower(first) = lower(n->>'first') and lower(last) = lower(n->>'last')) then
      insert into students (teacher_id, class_id, first, last, pin)
        values (t.id, p_class, n->>'first', n->>'last', lpad((floor(random() * 10000))::int::text, 4, '0'));
      added := added + 1;
    end if;
  end loop;
  return jsonb_build_object('added', added);
end $$;

create or replace function t_student(p_token text, p_student int, p_action text, p_class int default null) returns void
language plpgsql volatile security definer set search_path = public as $$
declare t teachers := _teacher(p_token);
begin
  if not exists (select 1 from students where id = p_student and teacher_id = t.id) then perform _err('Student not found.'); end if;
  if p_action = 'reset_pin' then update students set pin = lpad((floor(random() * 10000))::int::text, 4, '0') where id = p_student;
  elsif p_action = 'unlock' then update students set fails = 0, locked_until = null where id = p_student;
  elsif p_action = 'deactivate' then update students set active = false where id = p_student; delete from student_sessions where student_id = p_student;
  elsif p_action = 'activate' then update students set active = true where id = p_student;
  elsif p_action = 'move' then
    if not exists (select 1 from classes where id = p_class and teacher_id = t.id) then perform _err('Class not found.'); end if;
    update students set class_id = p_class where id = p_student;
  else perform _err('Unknown action.'); end if;
end $$;

-- p_rows: [{"a": "N1", "opens": iso, "due": iso, "closes": iso}, ...]
create or replace function t_set_schedule(p_token text, p_rows jsonb) returns void
language plpgsql volatile security definer set search_path = public as $$
declare t teachers := _teacher(p_token); r jsonb;
begin
  for r in select * from jsonb_array_elements(p_rows) loop
    if (r->>'due')::timestamptz < (r->>'opens')::timestamptz or (r->>'closes')::timestamptz < (r->>'due')::timestamptz then
      perform _err('For each night: opens ≤ due ≤ closes.');
    end if;
    insert into schedules (teacher_id, assignment_id, opens, due, closes)
      values (t.id, r->>'a', (r->>'opens')::timestamptz, (r->>'due')::timestamptz, (r->>'closes')::timestamptz)
      on conflict (teacher_id, assignment_id) do update set opens = excluded.opens, due = excluded.due, closes = excluded.closes;
  end loop;
  -- recompute late days for finished work under the new dates
  update states x set late_days = _school_days_late(sc.due, x.finished_at)
    from students s, parts pa, problems p, assignments a, schedules sc
   where s.id = x.student_id and s.teacher_id = t.id and not s.is_test and x.correct and x.finished_at is not null
     and pa.id = x.part_id and p.id = pa.problem_id and p.set_id = any(a.set_ids)
     and sc.teacher_id = t.id and sc.assignment_id = a.id
     and not exists (select 1 from ext_dates e2 where e2.student_id = s.id and e2.assignment_id = a.id);
end $$;

create or replace function t_extension(p_token text, p_student int, p_assignment text, p_due timestamptz, p_closes timestamptz) returns void
language plpgsql volatile security definer set search_path = public as $$
declare t teachers := _teacher(p_token); s students; d record;
begin
  select * into s from students where id = p_student and teacher_id = t.id;
  if s.id is null then perform _err('Student not found.'); end if;
  if p_due is null then delete from ext_dates where student_id = p_student and assignment_id = p_assignment;
  else
    insert into ext_dates values (p_student, p_assignment, p_due, greatest(p_closes, p_due))
      on conflict (student_id, assignment_id) do update set due = excluded.due, closes = excluded.closes;
  end if;
  select * into d from _dates(s, p_assignment);
  update states x set late_days = _school_days_late(d.due, x.finished_at)
    from parts pa, problems p, assignments a
   where x.student_id = s.id and x.correct and x.finished_at is not null and pa.id = x.part_id and p.id = pa.problem_id
     and a.id = p_assignment and p.set_id = any(a.set_ids);
end $$;

create or replace function t_reset_work(p_token text, p_student int, p_assignment text) returns void
language plpgsql volatile security definer set search_path = public as $$
declare t teachers := _teacher(p_token);
begin
  if not exists (select 1 from students where id = p_student and teacher_id = t.id) then perform _err('Student not found.'); end if;
  delete from states x using parts pa, problems p, assignments a
   where x.student_id = p_student and pa.id = x.part_id and p.id = pa.problem_id and a.id = p_assignment and p.set_id = any(a.set_ids);
end $$;

-- Hidden test student for "Preview as student". p_reset wipes the test student's work.
create or replace function t_preview(p_token text, p_reset boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare t teachers := _teacher(p_token); sid int; tok text;
begin
  select id into sid from students where teacher_id = t.id and is_test;
  if sid is null then
    insert into students (teacher_id, first, last, pin, is_test) values (t.id, 'Test', 'Student', 'xxxx', true) returning id into sid;
  end if;
  if p_reset then delete from states where student_id = sid; end if;
  tok := _token();
  insert into student_sessions values (tok, sid, now() + interval '1 day');
  return jsonb_build_object('token', tok);
end $$;

-- Full answer key (all teachers can view; only the admin can switch questions on/off).
create or replace function t_question_bank(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare t teachers := _teacher(p_token);
begin
  return (select jsonb_agg(jsonb_build_object('set', jsonb_build_object('id', h.id, 'title', h.title, 'calc', h.calc),
    'problems', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'n', p.n, 'title', p.title, 'stem', p.stem, 'topic', p.topic, 'std', p.std, 'active', p.active,
                   'parts', (select jsonb_agg(jsonb_build_object('id', pa.id, 'label', pa.label, 'prompt', pa.prompt, 'kind', pa.kind, 'spec', pa.spec,
                               'answer', pa.answer, 'answer_display', pa.answer_display, 'hints', pa.hints, 'explanation', pa.explanation) order by pa.ord)
                             from parts pa where pa.problem_id = p.id)) order by p.n), '[]')
                 from problems p where p.set_id = h.id)) order by h.id)
    from hw_sets h);
end $$;

-- ---------------- ADMIN API ----------------
create or replace function a_toggle_problem(p_token text, p_problem text, p_active boolean) returns void
language plpgsql volatile security definer set search_path = public as $$
declare t teachers := _admin(p_token);
begin update problems set active = p_active where id = p_problem; end $$;

create or replace function a_teachers(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare t teachers := _admin(p_token);
begin
  return (select coalesce(jsonb_agg(jsonb_build_object('id', te.id, 'name', te.name, 'email', te.email, 'is_admin', te.is_admin, 'active', te.active,
            'classes', (select count(*) from classes c where c.teacher_id = te.id and c.active),
            'students', (select count(*) from students s where s.teacher_id = te.id and s.active and not s.is_test)) order by te.name), '[]')
          from teachers te);
end $$;

create or replace function a_teacher(p_token text, p_action text, p_teacher int, p_name text, p_email text, p_password text) returns void
language plpgsql volatile security definer set search_path = public, extensions as $$
declare t teachers := _admin(p_token);
begin
  if p_action = 'add' then
    if coalesce(trim(p_name), '') = '' or coalesce(trim(p_email), '') = '' then perform _err('Name and email are required.'); end if;
    if length(coalesce(p_password, '')) < 8 then perform _err('Starting password needs at least 8 characters.'); end if;
    if exists (select 1 from teachers where lower(email) = lower(trim(p_email))) then perform _err('That email already has an account.'); end if;
    insert into teachers (name, email, pw_hash) values (trim(p_name), lower(trim(p_email)), extensions.crypt(p_password, extensions.gen_salt('bf')));
  elsif p_action = 'reset_password' then
    if length(coalesce(p_password, '')) < 8 then perform _err('New password needs at least 8 characters.'); end if;
    update teachers set pw_hash = extensions.crypt(p_password, extensions.gen_salt('bf')) where id = p_teacher;
    delete from teacher_sessions where teacher_id = p_teacher;
  elsif p_action = 'deactivate' then
    if p_teacher = t.id then perform _err('You can''t turn off your own account.'); end if;
    update teachers set active = false where id = p_teacher; delete from teacher_sessions where teacher_id = p_teacher;
  elsif p_action = 'activate' then update teachers set active = true where id = p_teacher;
  else perform _err('Unknown action.'); end if;
end $$;

create or replace function a_set_scoring(p_token text, p_scoring jsonb) returns void
language plpgsql volatile security definer set search_path = public as $$
declare t teachers := _admin(p_token);
begin
  if not (p_scoring ? 'max_attempts' and p_scoring ? 'wrong_pct' and p_scoring ? 'hint_costs' and p_scoring ? 'floor_pct' and p_scoring ? 'late_pct_per_day') then
    perform _err('Missing a scoring setting.');
  end if;
  update settings set scoring = p_scoring, updated_at = now() where id = 1;
end $$;

create or replace function a_defaults(p_token text, p_rows jsonb) returns void
language plpgsql volatile security definer set search_path = public as $$
declare t teachers := _admin(p_token); r jsonb;
begin
  for r in select * from jsonb_array_elements(p_rows) loop
    update assignments set opens = (r->>'opens')::timestamptz, due = (r->>'due')::timestamptz, closes = (r->>'closes')::timestamptz where id = r->>'a';
  end loop;
end $$;

create or replace function a_no_school(p_token text, p_day date, p_note text, p_remove boolean) returns void
language plpgsql volatile security definer set search_path = public as $$
declare t teachers := _admin(p_token);
begin
  if p_remove then delete from no_school where day = p_day;
  else insert into no_school values (p_day, p_note) on conflict (day) do update set note = excluded.note; end if;
end $$;

-- ---------------- PERMISSIONS ----------------
do $$ declare f text; begin
  -- helper functions stay private
  foreach f in array array['_err(text)','_token()','_scoring()','_student(text)','_teacher(text)','_admin(text)',
    '_school_days_late(timestamptz,timestamptz)','_dates(students,text)','_status(students,text)','_part_points(text)',
    '_pct(boolean,boolean,int,int,int)','_grade(text,jsonb,jsonb,jsonb)','_part_json(students,parts,numeric,boolean)',
    '_part_context(students,text)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['hw_teachers()','hw_classes(int)','hw_students(int)','hw_login(int,text)','hw_logout(text)',
    'hw_my_assignments(text)','hw_assignment(text,text)','hw_submit(text,text,jsonb)','hw_hint(text,text)',
    't_login(text,text)','t_logout(text)','t_change_password(text,text,text)','t_data(text)','t_class(text,text,int,text)',
    't_add_students(text,int,jsonb)','t_student(text,int,text,int)','t_set_schedule(text,jsonb)',
    't_extension(text,int,text,timestamptz,timestamptz)','t_reset_work(text,int,text)','t_preview(text,boolean)','t_question_bank(text)',
    'a_toggle_problem(text,text,boolean)','a_teachers(text)','a_teacher(text,text,int,text,text,text)','a_set_scoring(text,jsonb)',
    'a_defaults(text,jsonb)','a_no_school(text,date,text,boolean)'] loop
    execute format('revoke all on function %s from public', f);
    execute format('grant execute on function %s to anon, authenticated', f);
  end loop;
end $$;
