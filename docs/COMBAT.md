# Directional sword combat

The sparring yard is east of the school at (19, -19). Press F near the swordsman to start or stop. F6 from free hub movement teleports to the yard and begins practice. No sword purchase is required: an unequipped player borrows the Warden greatsword for the bout. Owned equipment is used if equipped. Loan equipment never enters the inventory.

The design is a read-and-answer duel in four lanes, read from the player's side: High, Right, Low, Left. The same lane index is a block for the defender and a cut for the attacker, so a Right guard meets a Right cut. Blade choreography is authored in that screen space and mirrored onto each rig, so a Right guard sits on the player's right for both fighters, in third person and in first person.

## Controls

WASD moves; in first and third person the view softly locks onto the swordsman, so W closes, S gives ground and A/D circle. Arrows select the lane. Outside first person the free mouse also steers the lane with a short swipe; holding RMB does the same in every camera. LMB is a light cut, Q or Shift+LMB a heavy one, RMB the guard, Space a quickstep. K opens combat skills outside a bout; K or Escape closes it.

Two things can happen inside a swing. Changing lane in the first half of a windup is a feint: the cut restarts from its chamber in the new lane for 6 stamina, once per swing. Pressing guard in the first half of a windup pulls the blow for 4 stamina and leaves an ordinary guard up, never a perfect one. An attack pressed in the last 0.22 seconds of a recovery is buffered and starts the moment the fighter is free; a guard that is still held after a recovery rises again as an ordinary guard.

## Reading the duel

The reticle is drawn over the swordsman's chest. Gold is the player's lane, brighter while guarding and white while a perfect window is open. Blue is his guard; a white pulsing guard is sharp, meaning he is set to parry that lane, so feint or change lane. Red is the incoming cut: the wedge thickens through his windup, the inner ring fills, and both jump lanes with a FEINT flash when he feints. A gold ring is the counter window and marks the opposite lane. Three pips beneath the reticle track the current form and point at its next lane. The outer arc is his health, the thin orange arc his exhaustion.

## Rules

Matching lanes block. A newly raised matching guard within 0.20 seconds of impact is perfect and costs no stamina. Held blocks cost 18 stamina against light attacks and 28 against heavies; a blocked heavy still chips 12% of its damage through. Changing lanes does not reset timing; rapid taps have a 0.32-second rearm lock. Perfect blocks inflict 38 attacker exhaustion, throw the attacker into a 1.05-second recovery, and open a 1.05-second counter opportunity. Any attack begun inside the counter window is a riposte with a 22% shorter windup; the Turning edge skill makes an opposite-lane riposte deal 65% more damage. An attack spends the one-strike counter opportunity even if it misses.

Two swings committed to the same lane clash: neither lands, both fighters are thrown into a 0.55-second recovery, both lose 8 stamina and both chains reset. A hit interrupts a swing that is less than 40% through its windup; a committed light swing carries on through a light hit, so late trades happen; a heavy hit interrupts anything. A missed swing adds 0.14 seconds of recovery and the swordsman punishes it.

Two forms are known from the start. Crossing cut is Left, Right, High; its finisher forces its way through a held guard for 70% damage and 20 exhaustion instead of being blocked. Serpent's coil is Low, High, Low; its finisher deals 50% more and adds 30 exhaustion to a blocking guard. Cuts must connect (hit or be blocked) within 1.8 seconds of each other, and taking a hit resets the chain.

Quickstep lasts 0.28 seconds, with invulnerability bounded to its middle 0.20 seconds. It uses normal character collision and costs 24 stamina, reduced to 19 by Economy of motion. Weapon stamina, speed, damage and upgrades apply to attacks. Armor protection reduces incoming damage. Research health, stamina and recovery bonuses remain additive with leveling. Below 20% stamina a fighter is winded: windups are 15% slower and footwork 15% slower.

Exhaustion reaches 100 through perfect blocks and sustained pressure against a guard. It disables guard for three seconds and increases incoming damage by 50%; a heavy blow on an exhausted fighter is a finishing blow at double damage. A guard without sufficient stamina breaks. Attacks resolve once at the strike phase and only within 2.65 metres. This is a timing-and-range duel, not per-triangle sword collision.

## The sparring partner

The bout opens with a 1.2-second salute during which he closes to measure but does not attack. He keeps a preferred distance of about two metres, circles when he has it, closes when he does not, and gives ground to breathe when his stamina falls under 25. He prefers to attack lanes the player is not guarding, occasionally throws a double (a second quick cut from another lane before the guard resets), and punishes a missed swing immediately. When the player begins a swing he reads the shown lane after a short delay and usually answers it; a feint halves that chance and delays his second read. From level 2 he feints himself, from level 3 he sometimes sets a sharp guard that parries the shown lane, and each level shortens his reactions and windups a little. His health grows by 12 per player level and his damage by 1.2. All of this is tuned for readability first: every attack is telegraphed on the reticle and above his head.

## Feedback

Impacts freeze the frame for 40 to 120 milliseconds by weight (clashes 100, finishing and critical blows 120), shake the camera, flash a light, throw sparks at the contact point, ring or thud with sounds synthesised at start-up (the repository has no sword recordings), and float a damage number. Blades leave a fading trail through the cut. A posture layer runs before the arm solver on both rigs: a forward-set ready stance, the chest coiling behind a chamber and driving through a cut, a flinch on hits and a slump when exhausted. The player's own hits pulse a red vignette. Banners call the salute, fight, perfect blocks, parries, feints, clashes, broken guards, completed forms, victory and defeat.

## Progression

A victory gives 60 XP and 25 gold, plus 20 XP for a flawless bout of at least eight seconds. The first level requires 100 XP, increasing by 40 each level. Every level grants one skill point, six health, four stamina, four percent base weapon damage and one protection. Equipment's existing level gates use this same level. Two three-node combat branches mix passive benefits and conditional moves. Purchases, XP and skill learning use the existing transactional save path. Failed saves roll back rewards or skill purchases. Defeat and leaving the arena do not destroy equipment; the partner resets after three seconds.

## Verification

`--combat-test` uses an isolated data directory and checks directional outcomes, guard timing, quickstep, exhaustion, feints, pulls, clashes, interrupts, chip damage, forms, buffering, held guards, partner scaling, lane mirroring, the posture-before-grip order and grip reach, the third-person lock, a six-second live bout, collision, input routing, rewards, level growth, prerequisites, critical direction and persisted skill data. It also captures third-person, first-person and skill-screen views. Menu, camera, school and research suites were run after integration. Tuning remains provisional until the player's hands-on feedback.
