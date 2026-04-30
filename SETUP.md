# PISTONWAVE — Launch Checklist

Everything below needs doing once, in order. Total time: about 20 minutes.

---

## STEP 1 — Run the Supabase schema (2 min)

1. Open the Supabase SQL editor:
   https://supabase.com/dashboard/project/ptmfshtisnjipsfwxfcu/sql/new

2. Open the file `schema.sql` from this folder, copy the entire contents, paste into the editor, click **Run**.

3. You should see no errors. This creates the four tables (challenges, submissions, votes, winners), the vote-count trigger, and all the Row Level Security policies. It also seeds Challenge 001 (Gobi Crossing) and the mock Hall of Fame entry.

---

## STEP 2 — Disable email confirmation (1 min)

This is important. Without this step, new users will get a confirmation email to a fake address and won't be able to log in.

1. Go to:
   https://supabase.com/dashboard/project/ptmfshtisnjipsfwxfcu/auth/providers

2. Click **Email** in the list.

3. Toggle **Confirm email** to OFF.

4. Click **Save**.

---

## STEP 3 — Create the GitHub repo (2 min)

1. Go to https://github.com/new

2. Repository name: `pistonwave`

3. Set it to **Public**.

4. Do NOT check "Add a README file" — leave everything else blank.

5. Click **Create repository**.

---

## STEP 4 — Push the code (3 min)

Open Terminal. Navigate to the pistonwave folder (wherever you saved it), then run these five commands one at a time:

```bash
git init
git add .
git commit -m "Launch: live Supabase backend"
git remote add origin https://github.com/maxmichalski738/pistonwave.git
git branch -M main
git push -u origin main
```

If it asks for your GitHub credentials, use your GitHub username and a Personal Access Token (not your password). To create a token: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token → tick "repo" → generate.

---

## STEP 5 — Deploy to Vercel (3 min)

1. Go to https://vercel.com and sign in with GitHub.

2. Click **Add New… → Project**.

3. Find `pistonwave` in the list and click **Import**.

4. Leave all settings as default — Vercel will detect it's a static site automatically.

5. Click **Deploy**. Wait ~30 seconds.

6. You'll get a URL like `pistonwave.vercel.app` — the site is live at this address immediately.

---

## STEP 6 — Add your custom domain in Vercel (2 min)

1. In your Vercel project, go to **Settings → Domains**.

2. Type `pistonwave.com` and click **Add**.

3. Vercel will show you a DNS record to add. It will look like one of these:

   - An **A record**: `@` → `76.76.21.21`
   - A **CNAME record**: `www` → `cname.vercel-dns.com`

   Note these down — you'll need them in the next step.

4. Also add `www.pistonwave.com` and set it to redirect to `pistonwave.com`.

---

## STEP 7 — Add DNS records in Namecheap (5 min)

1. Log into Namecheap: https://www.namecheap.com

2. Go to **Domain List → pistonwave.com → Manage → Advanced DNS**.

3. Delete any existing A records or CNAME records for `@` and `www`.

4. Add these two records:

   | Type  | Host | Value                  | TTL       |
   |-------|------|------------------------|-----------|
   | A     | @    | 76.76.21.21            | Automatic |
   | CNAME | www  | cname.vercel-dns.com   | Automatic |

5. Click the tick/save button for each record.

DNS can take up to 24 hours to propagate, but usually works within 15–30 minutes. Once it does, https://pistonwave.com is live.

---

## DAILY OPERATION — Crowning a winner and setting tomorrow's challenge

At midnight each day, submissions close automatically (Supabase enforces this via the `closes_at` column). To crown the winner and set up the next challenge:

### Crown the winner

Go to the Supabase SQL editor and run:

```sql
-- Find today's top submission
SELECT s.username, s.car_id, s.votes_count, s.user_id
FROM submissions s
WHERE s.challenge_id = '001'   -- change to current challenge ID
ORDER BY s.votes_count DESC
LIMIT 1;

-- Insert them as the winner (fill in the values from the query above)
INSERT INTO winners (challenge_id, user_id, username, car_id, votes_count, curator_note)
VALUES (
  '001',                           -- challenge ID
  'paste-user-id-here',            -- user_id from query above
  'PASTE_USERNAME_HERE',           -- username from query above
  173,                             -- car_id from query above
  247,                             -- votes_count from query above
  'Write your Jeremy Clarkson-style verdict here.'
);
```

### Add tomorrow's challenge

```sql
INSERT INTO challenges (id, number, title, description, max_price, drivetrain_blacklist, closes_at)
VALUES (
  '002',   -- increment the ID
  2,       -- increment the number
  'YOUR CHALLENGE TITLE',
  'Your challenge description. Use <strong> tags for emphasis.',
  10000,   -- budget cap in £ (null for no limit)
  ARRAY['4WD'],   -- drivetrains to ban, or ARRAY[]::text[] for none
  (current_date + interval '2 days - 1 second')  -- closes end of tomorrow
);
```

---

## TROUBLESHOOTING

**"User already registered" when signing up** — Email confirmation is still on. Redo Step 2.

**Votes not counting** — The trigger may not have created correctly. Re-run the schema SQL.

**Site shows old data after deploy** — Hard refresh the browser (Ctrl+Shift+R / Cmd+Shift+R).

**DNS not resolving after 2 hours** — Double-check there are no duplicate A records in Namecheap. Delete everything for `@` and `www` and re-add just the two records from Step 7.
