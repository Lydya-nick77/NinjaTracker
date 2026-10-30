# NinjaTracker

An Ashita v4 addon showing ninja-tool quantities, remaining Utsusemi shadows,
and Utsusemi recast timers.

## Loading

```text
/addon load NinjaTracker
```

Optionally add `/addon load NinjaTracker` to your existing startup script.
When upgrading from ninjatools, first run `/addon unload ninjatools`, then load
NinjaTracker. Replace the old load command in your startup script.
Settings now use the NinjaTracker settings folder. To retain old settings,
copy your old `config/addons/ninjatools` folder to `config/addons/NinjaTracker` while both
addons are unloaded, provided the destination does not already exist.

## Display

- Tool quantities turn gold below 20 and red at zero. The shadow indicator turns
  gold at one remaining shadow and red when no shadows remain.
- Below the shadow indicator, **Ichi** and **Ni** show live recast timers side by
  side. Remaining seconds are rounded up and shown in gold; **Ready** is green.
  Ready means the recast has expired, not that job, level, tool, or spell-learning
  requirements are met.
- When Utsusemi is active, click **Cancel Shadows** at the right edge of the counter row to remove
  the entire remaining Utsusemi effect, just like cancelling its status icon.
  Blink and other buffs are not cancelled. The counter updates when the server
  confirms removal; this does not cast a replacement Utsusemi.
- Display the Ninja tools in two columns. Missing tools show zero.
- Counts sum every stack in **main Inventory only**. Storage, Satchel, Sack,
  Case, wardrobes, and unopened toolbags are not counted.
- While visible and logged in, inventory is scanned every 0.25 seconds; shadows
  and recasts are read every frame from the client, including when loading with
  shadows active or a recast already running.
- Shadow statuses indicate **0**, **1**, **2**, **3**, or **4+**. The client uses
  the same status for four or more shadows, so this addon does not claim an
  exact count above three. Blink is not counted as Utsusemi.
- The display is hidden while logged out or without a player entity.

Drag the window title bar to move it. Position, text size, visibility, and lock
settings are saved per character using Ashita's settings library. Existing saved
positions and sizes are preserved when upgrading from the text-only display.
Legacy font-family, text-color, and background settings are not used by the
themed panel; its palette and styling are defined by the addon.

## Commands

```text
/nt help
/nt pos 30 200
/nt size 14
/nt lock
/nt show
/nt hide
/nt reload
/nt reset
```

`lock` toggles dragging. `size` accepts font heights from 8 to 40.
`reload` reads saved settings; `reset` restores defaults.
`/ninjatracker` also accepts all commands.

## Shadow cancellation

Shadow cancellation is available through the on-screen **Cancel Shadows**
button. The button removes all remaining Utsusemi shadows.
