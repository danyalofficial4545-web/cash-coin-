# Cash Coin

Cash Coin — Earn Coins, Convert to Cash.

## Run locally

```bash
npm install
npm run dev
```

The app includes a safe demo mode when Supabase environment variables are not available. Demo mode keeps the UI usable for review and logs a console warning instead of showing configuration errors to users.

## Lovable Cloud Supabase

Set only these client variables in Vercel/Lovable Cloud for the browser:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Run `supabase/schema.sql` in the Lovable Cloud SQL editor. It creates the tables, profile trigger, admin role whitelist, RLS policies, proofs bucket, referral reward trigger, and default settings. Never expose a service-role key in the browser.

The browser never throws a missing-environment error into the UI. If public variables are absent during a preview build, Cash Coin logs a console warning and uses safe demo mode. For server-side integrations, use `SUPABASE_URL` or `VITE_SUPABASE_URL`, then `SUPABASE_PUBLISHABLE_KEY` or `VITE_SUPABASE_PUBLISHABLE_KEY`, and only use `SUPABASE_SERVICE_ROLE_KEY` on the server.

## Admin whitelist

- Admin email: `muhammaddanyal4949@gmail.com`
- No username-based admin access

## Deployment

Vercel detects Vite automatically. Build command: `npm run build`; output directory: `dist`.

## Direct signup

The web client calls `supabase.auth.signUp` and immediately establishes a session (or performs an immediate password login fallback) before redirecting to `/dashboard`. The UI contains no email-verification screen or check-your-email message. For Supabase Auth to return a session immediately, Email provider **Confirm email** must be disabled in the Supabase project settings; this is an Auth provider setting, not a browser environment variable.
