-- Orbit v2: run this in Supabase Dashboard → SQL Editor.
-- All channels here are PUBLIC to any signed-in account.
create extension if not exists pgcrypto;
create table if not exists public.orbit_profiles(
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check(char_length(trim(display_name)) between 2 and 32),
  color text not null default '#d0ff7b' check(color ~ '^#[0-9A-Fa-f]{6}$'),
  created_at timestamptz not null default now()
);
create table if not exists public.orbit_channels(
  slug text primary key check(slug ~ '^[a-z0-9][a-z0-9_-]{1,31}$'),
  name text not null check(char_length(name) between 2 and 32),
  description text not null default '' check(char_length(description)<=120),
  emoji text not null default '✳' check(char_length(emoji) between 1 and 4),
  owner_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.orbit_messages(
  id uuid primary key default gen_random_uuid(),
  channel_slug text not null references public.orbit_channels(slug) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check(char_length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  edited_at timestamptz
);
create index if not exists orbit_messages_recent_idx on public.orbit_messages(channel_slug,created_at desc);
create table if not exists public.orbit_reactions(
  message_id uuid not null references public.orbit_messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null check(char_length(emoji) between 1 and 8),
  created_at timestamptz not null default now(),
  primary key(message_id,user_id,emoji)
);
insert into public.orbit_channels(slug,name,description,emoji,owner_id) values
 ('general','general','Anything and everything. Start here.','✳',null),
 ('gaming','gaming','Late-night lobbies, big plays, and good games.','◈',null),
 ('creative','creative','Works in progress. Big ideas. Tiny experiments.','✺',null),
 ('off-topic','off-topic','Conversations that belong nowhere else.','☻',null)
on conflict(slug) do nothing;
alter table public.orbit_profiles enable row level security;
alter table public.orbit_channels enable row level security;
alter table public.orbit_messages enable row level security;
alter table public.orbit_reactions enable row level security;
drop policy if exists "orbit_profiles_read" on public.orbit_profiles;
create policy "orbit_profiles_read" on public.orbit_profiles for select to authenticated using(true);
drop policy if exists "orbit_profiles_insert" on public.orbit_profiles;
create policy "orbit_profiles_insert" on public.orbit_profiles for insert to authenticated with check(user_id=auth.uid());
drop policy if exists "orbit_profiles_update" on public.orbit_profiles;
create policy "orbit_profiles_update" on public.orbit_profiles for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists "orbit_channels_read" on public.orbit_channels;
create policy "orbit_channels_read" on public.orbit_channels for select to authenticated using(true);
drop policy if exists "orbit_channels_insert" on public.orbit_channels;
create policy "orbit_channels_insert" on public.orbit_channels for insert to authenticated with check(owner_id=auth.uid());
drop policy if exists "orbit_messages_read" on public.orbit_messages;
create policy "orbit_messages_read" on public.orbit_messages for select to authenticated using(true);
drop policy if exists "orbit_messages_insert" on public.orbit_messages;
create policy "orbit_messages_insert" on public.orbit_messages for insert to authenticated with check(user_id=auth.uid());
drop policy if exists "orbit_messages_update" on public.orbit_messages;
create policy "orbit_messages_update" on public.orbit_messages for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists "orbit_messages_delete" on public.orbit_messages;
create policy "orbit_messages_delete" on public.orbit_messages for delete to authenticated using(user_id=auth.uid());
drop policy if exists "orbit_reactions_read" on public.orbit_reactions;
create policy "orbit_reactions_read" on public.orbit_reactions for select to authenticated using(true);
drop policy if exists "orbit_reactions_insert" on public.orbit_reactions;
create policy "orbit_reactions_insert" on public.orbit_reactions for insert to authenticated with check(user_id=auth.uid());
drop policy if exists "orbit_reactions_delete" on public.orbit_reactions;
create policy "orbit_reactions_delete" on public.orbit_reactions for delete to authenticated using(user_id=auth.uid());
alter table public.orbit_reactions replica identity full;
do $$
declare tab text;
begin
 foreach tab in array array['orbit_profiles','orbit_channels','orbit_messages','orbit_reactions'] loop
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=tab) then
   execute format('alter publication supabase_realtime add table public.%I',tab);
  end if;
 end loop;
end $$;

-- ORBIT V3: run this updated SQL again when upgrading an existing database.
-- Replies are constrained to their original channel and message identity is immutable.
alter table public.orbit_messages
  add column if not exists reply_to uuid references public.orbit_messages(id) on delete set null;
create index if not exists orbit_messages_reply_idx on public.orbit_messages(reply_to);

create or replace function public.orbit_validate_message()
returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    if new.user_id is distinct from old.user_id
      or new.channel_slug is distinct from old.channel_slug
      or new.reply_to is distinct from old.reply_to
      or new.created_at is distinct from old.created_at
      or new.id is distinct from old.id then
      raise exception 'Only message content may be edited';
    end if;
  end if;
  if new.reply_to is not null and not exists (
    select 1 from public.orbit_messages original
    where original.id = new.reply_to
      and original.channel_slug = new.channel_slug
  ) then
    raise exception 'Replies must point to a message in the same channel';
  end if;
  return new;
end;
$$;
drop trigger if exists orbit_validate_message_trigger on public.orbit_messages;
create trigger orbit_validate_message_trigger
before insert or update on public.orbit_messages
for each row execute function public.orbit_validate_message();
