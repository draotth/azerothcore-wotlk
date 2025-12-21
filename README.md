# Solo-Friendly AzerothCore WotLK (3.3.5a)

A solo-friendly Wrath 3.3.5a realm built on **AzerothCore** with **Playerbots**, **AHBot**, and QoL modules. Designed so you can jump in, level smoothly with heirlooms, queue dungeons solo (with bots), and enjoy a functioning economy even with low population.

---

## Highlights

- **Playerbots**: Tank/Heal/DPS on demand; questing, dungeons, raids.
- **AHBot**: A living Auction House with believable listings and pricing.
- **QoL Modules**: AoE loot, account-wide mounts/achievements, reward-by-played-time, transmog, Solo LFG.
- **Starter Experience** (via first-login starterpack module): gold, bags, class-appropriate heirlooms, auto-maxed cooking/fishing/first aid (with recipes), free class “fun” glyph bundles, all flight paths unlocked, dual spec, and optional auto-join to configurable faction guilds.

> Faction auto-join guilds are **configurable**. If you leave a guild name blank, no guild is created and new characters will not auto-join one.

---

## What Players Experience

### First Login
- **Starter gold** for immediate training/repairs.
- **Four 16-slot bags**.
- **Class-appropriate heirlooms** (XP shoulders/chest, weapons, trinkets; XP ring if enabled).
- **Max-level Cooking/Fishing/First Aid + recipes** (configurable per skill).
- **Fun/Cosmetic glyph bundles**: class-specific minor glyphs are auto-granted at the level they unlock (retroactive on login, never duplicated).
- **All flight paths unlocked** (optional).
- **Dual Spec** unlocked (optional).
- **Auto-guild join** (optional):  
  - Alliance → configurable name (e.g., `Voidlight`)  
  - Horde → configurable name (e.g., `Stormlight`)

### Playing Solo
- Queue **Solo LFG**; bots fill roles so dungeons pop even if you’re alone.
- **Playerbots** use class utilities (summons, portals, rez, etc.) and support questing/raids.

### Economy
- **AHBot** populates the auction house with curated item pools across qualities/categories, continuously updating.

### Account-wide Goodies
- **Account-wide mounts** and **account-wide achievements** reduce alt grind.
- **AoE loot** speeds up farming.

### Style
- **Transmog**: customize your look while keeping stats, per module config.

---

## Tech Stack & Layout

- **Docker** with `docker compose` for world/auth/database/client-data init.
- External ports (customized to avoid conflicts):
  ```
  DOCKER_WORLD_EXTERNAL_PORT=10903
  DOCKER_SOAP_EXTERNAL_PORT=10902
  DOCKER_AUTH_EXTERNAL_PORT=10901
  DOCKER_DB_EXTERNAL_PORT=10900
  ```
- Key paths (repo root):
  - Core: `src/server/...`
  - Modules: `modules/*`
  - Host configs: `conf/dist/*`, `conf/modules/*`
  - Container configs (runtime): `/azerothcore/env/dist/etc/*`

---

## Modules Enabled

- `mod-playerbots`
- `mod-ahbot`
- `mod-aoe-loot`
- `mod-account-mounts`
- `mod-account-achievements`
- `mod-reward-played-time` (reward system)
- `mod-transmog`
- `mod-solo-lfg`

> Configs load from `/azerothcore/env/dist/etc/modules/*.conf`. Host copies live in `conf/modules/*.conf`.

---

## Getting Started

### 1) Prereqs
- Docker & docker compose installed.

### 2) Configure Environment
Edit `conf/dist/env.docker` (or your env file) and confirm ports:
```
DOCKER_WORLD_EXTERNAL_PORT=10903
DOCKER_SOAP_EXTERNAL_PORT=10902
DOCKER_AUTH_EXTERNAL_PORT=10901
DOCKER_DB_EXTERNAL_PORT=10900
```

### 3) Build & Run
```bash
docker compose build ac-worldserver
docker compose up -d
docker compose logs -f ac-worldserver
```

You should see all databases up-to-date and modules loading (playerbots initialized, AHBot update cycles, transmog cache loaded, etc.).

### 4) Copy Module Configs (first run on host)
```bash
chmod +x tools/ac-prepare-module-confs.sh
./tools/ac-prepare-module-confs.sh
```
This copies `modules/**/conf/*.conf.dist` → `conf/modules/*.conf` and into the container’s `/azerothcore/env/dist/etc/modules`.

### 5) Import Module SQL (if not already applied. May not be required since we have the normalize tool)
Use the provided importer (adjust to your script name if different):
```bash
chmod +x tools/ac-import-module-sql.sh
./tools/ac-import-module-sql.sh
```
This applies SQL under `modules/**/data/sql/**` to the correct DB (`acore_world`, `acore_characters`, `acore_auth`, `acore_playerbots`).

> You should no longer see “table missing” errors like `mod_auctionhousebot` or `custom_unlocked_appearances`.

### 6) Set Realm Address
Set the `realmlist` address/port so remote clients connect to the right host. Defaults come from `.env` (falls back to `10.9.29.4:10903`):
```bash
chmod +x tools/ac-set-realmlist.sh
./tools/ac-set-realmlist.sh --address 10.9.29.4:10903
```
Use `--port` or `--realm-id` if you need to override the detected world port or target only a specific realm row.

---

## Connecting a Client

Set your client realmlist to the host/IP of your server and world port:
```
set realmlist <your-host-ip>:10903
```
Create an account, log in, and test with a fresh character.

---

## Configuration Notes

- **Faction Auto-Join Guilds** (starterpack module):
  - Alliance guild name: set to a non-empty string to auto-create & auto-join; leave blank to disable.
  - Horde guild name: same behavior.
- **Secondary Skills Sync**: when `FirstLoginStarterpack.SecondarySkills.SyncWithLevel = 1`, cooking/fishing/first aid ranks are automatically bumped at level milestones (5/10/20/35/50/65) and trainer/vendor recipes that don't require rep are auto-taught.
  - Existing characters are caught up on login and on every future level, so they retroactively learn all recipes unlocked by their current level.
- **Fun Glyph bundles**: `FirstLoginStarterpack.FunGlyphs.Enable` grants a curated set of class-specific cosmetic glyph items. Grants trigger at the glyph’s required level (catch-up happens on first login) and only hand out the glyphs the character is eligible for at that level.

- **DK Creation**: enabled for all accounts via Docker env/core config (if you elected that option).

- **AHBot**: tune in `mod_ahbot.conf` (counts, quality distribution, pricing, update cadence).

- **Playerbots**: tune in `playerbots.conf` (difficulty, composition, invite behavior).

- **Account-wide modules**: configure inclusion/exclusions, scope, and rules in their respective `.conf` files.

- **Transmog**: configure rules/costs/vendors in `transmog.conf` and related SQL/NPC spawns.

### AHBot Account Wiring

1. Start (or ensure) the database container is up:  
   `docker compose up -d ac-database`
2. Query the `ahbot` account id (“account GUID”) from `acore_auth.account`:  
   `docker compose exec ac-database mysql -h127.0.0.1 -P3306 -uroot -p${DOCKER_DB_ROOT_PASSWORD:-password} -Nse "SELECT id FROM acore_auth.account WHERE username='ahbot';"`
   - The current install returns `63`.
3. Set that value in `conf/modules/mod_ahbot.conf`:  
   `AuctionHouseBot.Account = 63` (leave `AuctionHouseBot.GUID = 0` unless you’ve created a dedicated character for the bot).

## Dev Notes

- Docker plaintext worldserver build (for debugging build failures): `cd /home/dan/azerothcore-wotlk && docker compose build --progress=plain ac-worldserver`

---

## Troubleshooting

- **“Your database structure is not up to date”**  
  Re-run the module SQL importer to apply missing tables/updates.
- **Module configs not loading**  
  Ensure `conf/modules/*.conf` exist on host and verify they appear at `/azerothcore/env/dist/etc/modules/` in the worldserver container.
- **Solo LFG patching**  
  If Solo LFG requires core patches, apply them from the module’s README and rebuild. Make the patch script idempotent.

---

## Roadmap / Not Implemented Yet

- Armor-proficiency milestone handouts (e.g., mail→plate transitions).
- Solo LFG: confirm required patches and full Playerbots interplay.
- Final AHBot tuning (auction counts, category weighting, price scalars).
- Transmog vendor placement/cost rules polish.
- Account-wide modules: detailed policy decisions for mounts/achievements.
- Ops polish: idempotent SQL/config scripts with clearer logging; optional post-install seeding (MOTD, server mail templates, welcome mail).

---

## License / Credits

- Core: **AzerothCore** (www.azerothcore.org)
- Playerbots: **mod-playerbots** community fork
- Other modules: respective authors/maintainers

This project aggregates community modules to deliver a smooth solo-friendly Wrath experience. Please support original projects and contributors.
