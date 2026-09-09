# Archive research

Press F at the researcher to open the archive. Trees show prerequisites and required ranks, with the strongest studies at the ends. The journal records completions and current bonuses. All balance values below are provisional for the test.

## Trees

- **Character:** Conditioning opens Vitality (3 ranks) and Endurance (3). Endurance leads to Measured Breathing (2), then the branches converge at Unbroken Resolve. Fully researched totals: 150 maximum health, 134 maximum stamina, and +20% stamina recovery. These values are exposed by the player for the upcoming combat system; the hub does not yet simulate combat health or stamina.
- **Equipment:** Metallurgy opens Deeper Enchantments (4) and Stable Tempering (4). Both lead to Beyond the Limit (3), then Masterwork Theory. Future successful upgrade gains can reach 25% of base damage/protection per attempt; the maximum item rank rises from +5 to +8. Existing item gains are stored individually and never improve retroactively.
- **Trade:** Appraisal branches into Trusted Customer (3) and Efficient Forging (3), then Guild Charter. The finished tree reduces purchase and upgrade gold costs by 25%. Displayed prices and actual charges use the same formula, rounded up.
- **Scholarship:** Organized Study opens the third research desk and Detailed Field Notes (2), then the fourth desk. Offline speed starts at 25% and can reach 50% through Field Notes.
- **Hub:** A visible WIP branch for village planning, gardens and workshops. It cannot take payment or start timers until actual hub upgrades are implemented.

## Time, payment and pausing

Two studies can run at once initially, eventually four. Studies have either one rank or up to three/four ranks. A rank must finish before the next rank can start. There is no automatic queue: choose each next study yourself.

Entry studies use gold. Later ranks and branches cost gold plus diamonds. The next rank's exact cost and duration are shown before starting. Timers range from 15 seconds to 10 minutes of play; offline estimates are also displayed.

Costs are paid once at start. Pause preserves the paid project and remaining time while freeing its desk. Resuming requires a free desk and does not charge again. Projects cannot be cancelled or refunded. Paused projects stay paused while closed.

Completed bonuses activate automatically. A notification appears even outside the archive, and the journal retains the result until acknowledged. Multiple simultaneous completions share one notification. Continue advances saved projects at the slower offline rate, persists the result immediately, and reports unread completions. Offline speed upgrades apply from their completion time, not retroactively to the whole absence. Title-screen time counts at the offline rate when continuing; open gameplay menus retain normal research speed.

## Equipment survival and saved gains

Base survival for attempts to reach +1 through +8 is 85%, 72%, 60%, 48%, 35%, 28%, 22%, and 16%. Research adds up to 40 percentage points. The first three upgrade attempts may reach 100%; later attempts are capped below certainty. With the complete tree, the final +8 attempt has 56% survival. Failure still consumes the gold and permanently destroys that exact copy.

Each successful attempt adds its current stat gain to an item-specific stored total. Research improves only future attempts, including future attempts on an older item. Legacy equipment preserves its prior total when migrated. If a research completion changes the cost, odds or stat gain of a pending upgrade confirmation, the shop requests a fresh review before spending anything.

## Persistence and validation

Research shares the atomic hub save with currency and equipment. Start, pause, resume and completion save immediately. Failed saves roll the operation back. Active timers are also included in the ordinary hub autosave. Separate test saves keep simulated resources out of normal progression; there is no debug grant in the UI.

Run `./play.fish -- --research-test` for native checks and captures, or add `--headless --fixed-fps 60` for the logic checks. Coverage includes all reachable branches, resource gates, concurrent timers, pause/resume, offline accounting, completion notifications, save failures, migration, non-retroactive item gains, quote changes, discounts and upgrade caps.
