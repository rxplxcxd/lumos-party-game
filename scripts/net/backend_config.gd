extends RefCounted
## Online-Konten (Supabase). Hier stehen nur die ÖFFENTLICHEN Werte des Supabase-Projekts:
##   SUPABASE_URL      = Projekt-URL, z. B. https://abcdefghijkl.supabase.co
##   SUPABASE_ANON_KEY = „anon“/„publishable“ Key (Supabase → Project Settings → API Keys)
## Niemals den service_role-/secret-Key eintragen – der Client-Key ist absichtlich öffentlich,
## geschützt wird über Row Level Security (supabase/schema.sql).
##
## Die CI überschreibt diese Datei vor dem Export, wenn im Repo die Actions-Variablen bzw. -Secrets
## SUPABASE_URL und SUPABASE_ANON_KEY gesetzt sind (.github/workflows/build-web.yml).
## Nativ lassen sie sich zusätzlich über die Umgebungsvariablen LUMOS_SUPABASE_URL/_KEY setzen.

const SUPABASE_URL := ""
const SUPABASE_ANON_KEY := ""
