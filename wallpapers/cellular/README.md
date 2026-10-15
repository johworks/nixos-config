# Cellular Life

A native Plasma 6 wallpaper, enabled only on `desktop` by
`hosts/desktop/cellular-wallpaper.nix`. It runs Conway's Game of Life with
wrapping edges, randomized density, and occasional mirrored starting worlds.
Each monitor gets an independent simulation.

The defaults are 12-pixel cells, eight generations per second, and a new random
world every two minutes. Fixed worlds and period-two oscillators restart after
ten quiet seconds. New cells glow pale green, older cells turn teal, and dead
cells leave fading trails. Rendering uses a small texture and the simulation is
capped at 240 × 160 cells per screen.

After rebuilding `desktop`, the user service selects **Cellular Life** on all
existing desktops at Plasma login. To select it immediately in an existing
session, run `systemctl --user start cellular-wallpaper`.

Right-click the desktop to pause/resume or generate a fresh seed. Under
**Desktop and Wallpaper → Wallpaper type → Cellular Life**, adjust cell size,
speed, and reseeding time. A different wallpaper can be selected there too;
the configured default is restored on the next login.

Run the simulation checks with:

```sh
node --test wallpapers/cellular/life.test.cjs
```
