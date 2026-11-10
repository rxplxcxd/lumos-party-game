-- Lumos Party – Supabase-Schema für Online-Profile.
-- Einmal im Supabase-Dashboard unter „SQL Editor“ ausführen (idempotent, darf mehrfach laufen).
--
-- Das Spiel speichert pro Konto ein JSON-Profil (Bestzeiten, Statistiken, Freischaltungen).
-- Row Level Security: Jeder Nutzer darf nur seine eigene Zeile lesen und schreiben.

create table if not exists public.profiles (
	id uuid primary key references auth.users (id) on delete cascade,
	name text not null default '',
	data jsonb not null default '{}'::jsonb,
	updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
	for select to authenticated using ((select auth.uid()) = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
	for insert to authenticated with check ((select auth.uid()) = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
	for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

grant select, insert, update on public.profiles to authenticated;
