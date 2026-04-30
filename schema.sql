-- ============================================================
-- PISTONWAVE — Supabase Schema  (clean version, run once)
-- Supabase dashboard → SQL Editor → New query → paste → Run
-- ============================================================

-- Lets us generate random unique IDs
create extension if not exists "uuid-ossp";


-- ============================================================
-- TABLE 1: challenges
-- Stores each daily challenge (title, budget, rules, close time)
-- ============================================================
create table if not exists challenges (
  id                   text primary key,
  number               integer not null,
  title                text not null,
  description          text not null,
  max_price            integer,
  drivetrain_blacklist text[] default '{}',
  closes_at            timestamptz not null,
  created_at           timestamptz default now()
);


-- ============================================================
-- TABLE 2: submissions
-- One row per user per challenge — their car pick
-- ============================================================
create table if not exists submissions (
  id           uuid primary key default uuid_generate_v4(),
  challenge_id text references challenges(id) on delete cascade,
  user_id      uuid references auth.users(id) on delete cascade,
  username     text not null,
  car_id       integer not null,
  votes_count  integer default 0,
  created_at   timestamptz default now(),
  unique(challenge_id, user_id)
);


-- ============================================================
-- TABLE 3: votes
-- One row per vote — who voted on which submission
-- ============================================================
create table if not exists votes (
  id            uuid primary key default uuid_generate_v4(),
  submission_id uuid references submissions(id) on delete cascade,
  user_id       uuid references auth.users(id) on delete cascade,
  created_at    timestamptz default now(),
  unique(submission_id, user_id)
);


-- ============================================================
-- TABLE 4: winners
-- One row per challenge — the crowned winner + curator note
-- ============================================================
create table if not exists winners (
  id           uuid primary key default uuid_generate_v4(),
  challenge_id text references challenges(id) on delete cascade,
  user_id      uuid,
  username     text not null,
  car_id       integer not null,
  votes_count  integer not null default 0,
  curator_note text,
  created_at   timestamptz default now()
);


-- ============================================================
-- TRIGGER: keeps votes_count accurate automatically
-- When someone votes, submissions.votes_count goes up by 1.
-- When they un-vote, it goes back down.
-- ============================================================
create or replace function update_votes_count()
returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    update submissions set votes_count = votes_count + 1
    where id = NEW.submission_id;
  elsif TG_OP = 'DELETE' then
    update submissions set votes_count = greatest(0, votes_count - 1)
    where id = OLD.submission_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

drop trigger if exists votes_count_trigger on votes;
create trigger votes_count_trigger
  after insert or delete on votes
  for each row execute function update_votes_count();


-- ============================================================
-- SECURITY RULES
-- Controls who can read/write each table.
-- ============================================================
alter table challenges  enable row level security;
alter table submissions enable row level security;
alter table votes       enable row level security;
alter table winners     enable row level security;

-- Anyone (even not logged in) can read challenges
create policy "read challenges"
  on challenges for select using (true);

-- Anyone can read submissions
create policy "read submissions"
  on submissions for select using (true);

-- Logged-in users can submit — but only before the challenge closes
create policy "insert submissions"
  on submissions for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from challenges c
      where c.id = challenge_id
      and c.closes_at > now()
    )
  );

-- Anyone can read votes
create policy "read votes"
  on votes for select using (true);

-- Logged-in users can vote (but not on their own submission)
create policy "insert votes"
  on votes for insert
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from submissions s
      where s.id = submission_id
      and s.user_id = auth.uid()
    )
  );

-- Users can remove their own vote
create policy "delete own votes"
  on votes for delete
  using (auth.uid() = user_id);

-- Anyone can read the Hall of Fame
create policy "read winners"
  on winners for select using (true);


-- ============================================================
-- SEED DATA: the two challenges
-- ============================================================

-- Challenge 000: mock "yesterday" challenge — gives the Hall of Fame
-- something to show before anyone has actually won anything
insert into challenges (id, number, title, description, max_price, drivetrain_blacklist, closes_at)
values (
  '000', 0,
  'BANK HOLIDAY ROADSTER',
  'You''ve got <strong>£5,000 (mods included)</strong> to find the best little drop-top for a sunny bank holiday weekend. Bonus marks for not falling apart between Calais and Cannes.',
  5000,
  ARRAY['4WD'],
  now() - interval '1 day'
)
on conflict (id) do nothing;

-- Challenge 001: today's live challenge
insert into challenges (id, number, title, description, max_price, drivetrain_blacklist, closes_at)
values (
  '001', 1,
  'GOBI CROSSING',
  'You''ve got <strong>£5,000 (mods included)</strong> to cross the Gobi Desert. 1,610km of unforgiving sand, rock and wind. The catch — <strong>no 4x4s allowed</strong>. Pick something with character. Sensible is allowed. Stupid is encouraged.',
  5000,
  ARRAY['4WD'],
  (current_date + interval '1 day - 1 second')
)
on conflict (id) do nothing;

-- Hall of Fame seed: mock winner for the Bank Holiday Roadster challenge
-- (Mazda MX-5 NB, car ID 173 in the app's car list)
insert into winners (challenge_id, user_id, username, car_id, votes_count, curator_note)
values (
  '000',
  null,
  'NIGHTSHIFT_88',
  173,
  247,
  'The MX-5 is the obvious answer, the right answer, and the boring answer. Doesn''t matter — under five grand it''s the most reliable smile-per-mile thing on the planet. Three cans of WD40, a bottle of brake fluid, you''re sorted to the south of France. Well done.'
);

-- ============================================================
-- ALL DONE. Now go to:
-- Authentication → Providers → Email → turn OFF "Confirm email"
-- ============================================================
