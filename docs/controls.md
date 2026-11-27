# How to Play

## The goal

Knock your opponent off the stage until they run out of stocks (lives).

- Every hit adds to the opponent's **damage %** (shown at the bottom of the
  screen).
- The higher their %, the further your hits send them flying.
- A fighter who flies past the edge of the screen (the blast zone) loses a
  stock and respawns at 0%.
- Each player starts with **3 stocks**. Last fighter standing wins.

## Starting a match

On the title screen, choose a mode with **W / S** (or the **arrow keys**) and
press **Enter**:

- **VS CPU**: you play Lucy (player 1) against the computer, who plays David.
- **VERSUS**: two players on one keyboard.

After a match, press **Enter** on the results screen to return to the title
screen. **Esc** closes the game.

## Controls

| Action | Player 1 | Player 2 |
|---|---|---|
| Move left / right | A / D | Left / Right arrow |
| Aim up / down | W / S | Up / Down arrow |
| Jump (press again in the air to double jump) | Space | Right Shift |
| Dash | Left Shift | Right Ctrl |
| Attack | P | . (period) |
| Special | O | , (comma) |
| Strong | I | / (slash) |

## Moving

- **Walk:** hold left or right.
- **Run:** tap left or right twice quickly, then hold.
- **Jump:** one jump from the ground, plus one double jump in the air.
- **Drop through a platform:** hold down while standing on one of the thin
  platforms. The big main platform is solid.
- **Dash:** dashes in the direction you're holding, or the way you're facing
  if you hold nothing. Works on the ground and once per jump in the air.
- **No turning in the air:** once you leave the ground you keep facing the
  same way. Holding the other direction only drifts you backwards.

## Attacks

| Move | On the ground | In the air |
|---|---|---|
| **Attack** | Jab: fast, close range | Forward aerial: hits in front |
| **Attack + up** | Jab | Up aerial: hits above you |
| **Attack + down** | Jab | Down aerial: hits below you and sends them downward (a spike) |
| **Strong** | Side strong: slow wind-up, hits hard. Your best way to knock someone off. | Same as Attack (forward / up / down aerial) |
| **Special** | Neutral special | Neutral special |

- **B-reverse:** right after pressing Special, hold the opposite direction to
  turn around (and flip your momentum). This is the only way to turn in the
  air.
- **Landing cancels aerials:** if you land before an aerial's hit comes out,
  the attack is cancelled. Time your aerials.

## The characters

| | Lucy | David |
|---|---|---|
| Style | Fast: high run and air speed | Heavy: slower, falls faster |
| Gimmick | **Stun**: some hits stun the opponent | **Slow**: some hits put the opponent in slow motion |
| Moves with the gimmick | Jab, side strong, neutral special, up aerial | Jab, neutral special, up aerial |

**Stun:** the opponent is frozen in place for 1 second, in the air too, and
vibrates. Hitting them again with a stun move restarts the freeze. Every hit
while they're frozen is saved up: when the freeze ends, they're launched once,
as hard as the last hit, in the average direction of all of them. At most 5
stuns per combo, then stun can't be used for a moment.

**Slow:** the opponent moves at half speed for 5 seconds (a clock next to
their tag shows the time left). It can't be refreshed, and can't be applied
again for 3 seconds after it ends.

## Not in the game yet

These are planned (see `docs/scope.md`) but not built:

- Shield
- Short hop (a lower jump by tapping jump) and landing lag
- Combo scaling (shorter hitstun on long combos)

## Debug keys

For testing, not part of the final game.

| Key | What it does |
|---|---|
| F2 | Show / hide hitboxes and body boxes (on by default). In VS CPU it also shows the CPU's current state above its head. |
| F5 | Reload all data files (character stats, moves, stage, rules, CPU) without restarting |
