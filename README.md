# Orbit Chat v2

An original, responsive web chat application with an animated interface. The app is a single static `index.html`.

## Try it

Open [index.html](./index.html) in a browser. Without a backend, Orbit runs an interactive preview and stores demo data in this browser's local storage. Preview members are fictional examples.

## Enable real messaging

1. Create a free [Supabase](https://supabase.com/dashboard) project.
2. In the Supabase **SQL Editor**, run [orbit-schema.sql](./orbit-schema.sql) to create the four `orbit_*` tables, public channels, row-level security policies, and realtime publications.
3. Find **Project URL** and **publishable/anon key** in Supabase Project Settings → API.
4. In `index.html`, set the public config near the top:

```js
window.ORBIT_CONFIG = {
  supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
  supabasePublishableKey: 'YOUR_PUBLIC_KEY'
};
```

Never put a `service_role` or secret key in browser code.

5. Test with two separate accounts. Sign-up may require email confirmation.
6. In Supabase Auth settings, configure your Cloudflare Pages address as the Site URL, including the appropriate redirect URLs.

## Deploy for free on Cloudflare Pages

Cloudflare dashboard → Workers & Pages → Create Pages project → Connect to Git → choose this repository.

Choose branch `main`, framework preset **None**, no build command, output directory root `/`.

New pushes to `main` redeploy automatically.

## Features

- Public text channels, make new channels
- Email accounts (Supabase Auth)
- Send, receive, edit, and delete your own messages
- Emoji reactions, channel search, profiles, presence, typing indicators
- Accent colors, reduced-motion preference, compact mode
- Responsive layouts, keyboard shortcuts, offline preview

## Before a wider launch

Current rooms are **public to all authenticated users**. No private DMs or end-to-end encryption. Add moderation, anti-spam/rate-limits, reporting, account policies, and message pagination before public promotion. Supabase free-tier quotas apply.

The first Orbit prototype's `public.messages` table is not reused by Orbit v2.
