# Math 1 EOC Review

Nightly EOC review homework for NC Math 1 with built-in topic review, for the whole math department.

- **Students:** `index.html` — pick teacher → class → name → 4-digit PIN. Each night has a no-calculator set (Desmos locked) and a calculator set (pop-up Desmos), hints, instant feedback, and free 📘 review topics.
- **Teachers:** `teacher.html` — gradebook, insights (incl. topic mastery), classes & PINs, per-teacher due dates, Canvas export, answer key.
- **Admin:** the Admin tab adds teachers, sets the department scoring rules, default dates, and no-school days. Questions are switched on/off from the Answer key tab.

Answer keys live **only in Supabase**, never in this public repo. Grading happens on the server.

## One-time setup

1. **Supabase → New project.** Then **SQL Editor → New query**, paste all of [`supabase/schema.sql`](supabase/schema.sql), click **Run**.
2. In a new query, paste **`seed.sql`** (the questions + answer keys; shared privately, not in this repo) and click **Run**.
3. Create your admin account (new query, change the name/email/password first):
   ```sql
   insert into teachers (name, email, pw_hash, is_admin)
   values ('Mr. Crouch', 'you@school.org', extensions.crypt('ChangeMe-2027', extensions.gen_salt('bf')), true);
   ```
4. **Project Settings → API**: copy the Project URL and the publishable key into [`js/config.js`](js/config.js).
5. **GitHub → Settings → Pages**: deploy from branch `main`, folder `/ (root)`.
6. Open `…/teacher.html`, log in, change your password (click your name), add your classes and rosters, then add colleagues on the **Admin** tab.

## Updating questions

Re-running a new `seed.sql` updates question text, hints, and keys in place. It keeps student work, due dates, and on/off switches.
`schema.sql` is safe to re-run too (it never deletes data).

## Night plan (department default)

| Night | Assigned | Sets |
|---|---|---|
| 1 | Mon 1/4 | HW 1 (no calc) + HW 2 |
| 2 | Tue 1/5 | HW 3 + HW 4 |
| 3 | Wed 1/6 | HW 5 (no calc) + HW 6 |
| 4 | Thu 1/7 | HW 8 (no calc) + HW 7 |
| 5 | Fri 1/8 | HW 10 (no calc) + HW 9 |
| 6 | Mon 1/11 | HW 11 + HW 12 |
| 7 | Tue 1/12 | HW 13 + HW 14 |

Each night opens at 7:00 AM and is due the next school day at 7:30 AM; all nights close 1/13/27 at 11:59 PM by default. Each teacher can change their own dates.
