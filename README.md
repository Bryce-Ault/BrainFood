# BrainFood

Battleground buff assistant for Mages, Priests, Druids, and Paladins. One-click button to systematically buff every teammate during the prep phase — no manual targeting, no missed players, no wasted time.

## What It Does

When you enter a battleground, BrainFood scans your group/raid for unbuffed players and builds a priority queue. A button appears at the top of your screen — click it repeatedly and it will target each unbuffed player, cast your buff, then return to your previous target. Once everyone is buffed, it tells you so and turns green.

When the gates open, the button hides automatically so it stays out of your way during combat.

## Class-Specific Buff Logic

- **Mage:** Casts Arcane Intellect (recognizes Arcane Brilliance to avoid double-buffing)
- **Priest:** Casts Power Word: Fortitude (recognizes Prayer of Fortitude)
- **Druid:** Casts Mark of the Wild (recognizes Gift of the Wild)
- **Paladin:** Casts Blessing of Wisdom by default, but automatically switches to Blessing of Might for Warriors and Rogues

The addon checks for both single-target and raid-wide versions of each buff so it never wastes a cast on someone who's already covered.

## Smart Targeting

- Builds a queue of all unbuffed players in your group or raid (up to 40)
- Prioritizes special cases (e.g., Warriors/Rogues needing Might) before standard targets
- Skips players who are dead, offline, out of range, or already buffed
- Rescans every 3 seconds and whenever the group roster changes, so late-loading players get picked up automatically

## Battleground Lifecycle Awareness

- **Prep phase:** Button appears, scanning begins, click to buff
- **Gates open ("has begun"):** Button hides, scanning stops — zero clutter during combat
- **Leaving combat:** Rescans in case new players need buffs

## UI & Commands

- Draggable button — reposition it wherever you want
- `/bf` — Toggle the button on/off
- `/bf reset` — Reset button position to default

## Who Is This For?

If you play a buffing class in TBC Anniversary battlegrounds and you're tired of manually clicking through 15–40 players during the prep countdown, BrainFood handles it in seconds. One button, one job — feed those brains.
