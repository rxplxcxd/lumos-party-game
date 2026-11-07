extends Node
## Globaler Event-Bus. Systeme kommunizieren lose gekoppelt über diese Signale:
## Gameplay feuert Ereignisse, Kamera/Juice/Audio/Cutscenes reagieren darauf.

# --- Cutscenes & Kamera ---------------------------------------------------
signal cutscene_requested(id: String, ctx: Dictionary)
signal cutscene_started(id: String)
signal cutscene_finished(id: String)
signal camera_shake(strength: float, duration: float)
signal fov_punch(amount: float, duration: float)

# --- Juice ------------------------------------------------------------------
signal hitstop(duration: float)
signal haptic(strength: float, duration: float)

# --- Party-Brettspiel ---------------------------------------------------------
signal coins_changed(player: int, total: int, delta: int)
signal stars_changed(player: int, total: int, delta: int)
signal turn_started(player: int)
signal space_landed(player: int, space_type: String)

# --- Charaktere ---------------------------------------------------------------
signal player_reaction(player: int, reaction: String)

# --- Racer ----------------------------------------------------------------------
signal item_hit(victim: Node3D, item_id: String, attacker: Node3D)
signal lap_completed(racer: int, lap: int)

# --- UI -------------------------------------------------------------------------
signal toast(text: String, color: Color)
signal announcer(text: String)
signal settings_changed

## Zeitfahren: neuer Bestwert gespeichert (für Profil-Sync).
signal record_set(track_id: String, best_total: float, best_lap: float)
