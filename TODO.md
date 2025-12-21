# TODO

Tracked remaining work that’s not critical to play, but completes the vision.

## Starterpack / Class Content
- [x] Fill **heirloom lists for all classes** (Paladin done; add Warrior, DK, Hunter, Rogue, Priest, Shaman, Mage, Warlock, Druid).
- [ ] Add **armor-proficiency milestone** handouts (e.g., mail→plate transitions).
- [x] Auto-learn **cooking/fishing/first aid** and **recipes per level**.
- [ ] **First Aid level sync** to character level.
- [ ] Optional: **“Fun glyphs free”**; **spec glyphs via AH** enforcement (vendor/mail/logic).

## Solo LFG
- [ ] Read Solo LFG README and **apply required core patches** (create idempotent patch script).
- [ ] Verify **Playerbots ↔ Solo LFG** interplay (queue roles, pop logic, dungeon completion).

## AHBot
- [ ] Tune **auction counts**, **quality mix**, **category weighting**, **price scalars**.
- [ ] (If used) assign a dedicated **AH owner** account/character GUID in the config.

## Transmog
- [ ] Confirm vendor **spawns/rules/costs** in `transmog.conf` and DB.
- [ ] Decide **account-level vs character-level** unlock behavior (if supported by the module).

## Account-wide Modules
- [ ] **mod-account-mounts**: decide scope and exclusions.
- [ ] **mod-account-achievements**: decide which achievements are shared.
- [ ] **mod-reward-played-time**: configure thresholds/rewards to avoid overlap with starterpack.

## DK Creation & Core Configs
- [ ] Ensure **DK creation** from the start for all accounts is enabled in Docker env/core config.
- [ ] Reconfirm **all flight paths unlocked** handling (via starterpack or DB).

## Automation & Ops
- [ ] Make the **module SQL importer** and **config copier** fully **idempotent**, with clear logging.
- [ ] Add an optional **post-install seeding** script:
  - [ ] Set guild auto-join names as desired (or blank to disable).
  - [ ] Seed MOTD, server mail templates, welcome mail.
