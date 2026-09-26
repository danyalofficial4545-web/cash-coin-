# Cash Coin

Cash Coin — Earn Coins, Convert to Cash.

## Run locally

```bash
npm install
npm run dev
```

The app includes a safe demo mode when Supabase environment variables are not available. Demo mode keeps the UI usable for review and logs a console warning instead of showing configuration errors to users.

## Lovable Cloud Supabase

Set only these client variables in Vercel/Lovable Cloud:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Run `supabase/schema.sql` in the Lovable Cloud SQL editor. It creates the tables, profile trigger, admin role whitelist, RLS policies, and default settings. Never expose a service-role key in the browser.

## Admin whitelist

- Emails: `muhammaddanyal4949@gmail.com`, `muhammaddanyal4545@gmail.com`
- Usernames: `danyal955`, `danyal955163`, `danyal1953`

## Deployment

Vercel detects Vite automatically. Build command: `npm run build`; output directory: `dist`.
