# Systems direction

Captured from the author's hub brief. Blacksmith buying, equipping and upgrades are implemented; research and combat progression are still future work.

- Greatswords are the only weapon category.
- The blacksmith sells weapons and armor for gold dropped by enemies.
- A magician/researcher uses diamonds, a rarer enemy drop, for timed research.
- Research grants passives and bonuses; camp upgrades are a possibility to explore.
- Items require both enough currency and the appropriate level.
- Levels give skill points and evenly increase stats, rather than giving allocatable stat points. A possible secret stat remains undecided.
- Weapons and armor can be upgraded, with a chance of permanent destruction on failure.

## Deliberately unresolved

Research duration, online versus offline timing, queue rules, prices, stat formulas, XP sources, upgrade probabilities, and protection against destruction have not been decided. Do not silently turn prototype values into final balance.

## This pass

The blacksmith sells three greatswords and two full plate sets split into helmet, chest, gloves and boots. Equipment changes the animated player. Gold and level gates apply, duplicate copies are allowed, and there is no selling or debug currency control. Each copy can upgrade independently for gold, with permanent destruction possible from the first attempt. Transactions persist immediately, including destruction, and roll back on save errors.

Five ranks, the item prices and levels, survival chances (85/72/60/48/35 percent), 10 percent base-stat gains per rank and escalating gold cost are provisional test values. Future research will improve item survival and upgrade stat gains. Research comes next, then combat and actual gold/XP sources. The current shop allows free visual previews while the economy remains unavailable.
