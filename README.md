# BrainFood

Battleground and arena buff assistant for Mages, Priests, Druids, and Paladins. One-click button to systematically buff every teammate — no manual targeting, no missed players, no wasted time.

## What It Does

When you enter a battleground or arena, BrainFood scans your group/raid for unbuffed players and builds a priority queue. A button appears at the top of your screen — click it repeatedly and it will target each unbuffed player, cast your buff, then return to your previous target. Once everyone is buffed, it tells you so and turns green.

When the match starts, the button hides automatically so it stays out of your way during combat.

## Class-Specific Buff Logic

- **Mage:** Casts Arcane Intellect (recognizes Arcane Brilliance to avoid double-buffing). Skips Warriors and Rogues since they don't benefit from the intellect buff.
- **Priest:** Casts Power Word: Fortitude (recognizes Prayer of Fortitude)
- **Druid:** Casts Mark of the Wild (recognizes Gift of the Wild)
- **Paladin:** Casts Blessing of Wisdom (recognizes Greater Blessing of Wisdom) by default, but automatically switches to Blessing of Might for Warriors and Rogues

The addon checks for both single-target and raid-wide versions of each buff so it never wastes a cast on someone who's already covered. During the prep phase, buffs with less than 5 minutes remaining are treated as expired and will be refreshed.

## Smart Targeting

- Builds a queue of all unbuffed players in your group or raid (up to 40)
- Prioritizes special cases (e.g., Warriors/Rogues needing Might) before standard targets
- Skips players who are dead, offline, out of range, or already buffed
- Rescans every 3 seconds and whenever the group roster changes, so late-loading players get picked up automatically

## Match Lifecycle

- **Enter BG/arena:** Button appears, scanning begins, click to buff
- **Match starts ("has begun"):** Button hides, scanning stops — zero clutter during combat
- **Leaving combat:** Rescans in case new players need buffs
- **Outside BG/arena:** Button stays hidden unless manually toggled with `/bf`

## UI & Commands

- Draggable button — reposition it wherever you want
- `/bf` or `/brainfood` — Toggle the button on/off
- `/bf reset` — Reset button position to default

## Who Is This For?

If you play a buffing class in TBC Anniversary battlegrounds or arenas and you're tired of manually clicking through players before the match starts, BrainFood handles it in seconds. One button, one job — feed those brains.
