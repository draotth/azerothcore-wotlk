## Bug Tracking References

- Commits behind our playerbot fork of AzerothCore:  
  https://github.com/mod-playerbots/azerothcore-wotlk/compare/Playerbot...azerothcore%3Aazerothcore-wotlk%3Amaster

- Issues for the playerbot-maintained AzerothCore fork:  
  https://github.com/mod-playerbots/azerothcore-wotlk/issues

- Issues for upstream AzerothCore:  
  https://github.com/azerothcore/azerothcore-wotlk/issues

- Issues specific to the playerbots module:  
  https://github.com/mod-playerbots/mod-playerbots/issues

**Reminder:** before diving into any debugging session, verify that every checked-out repository (the root `azerothcore-wotlk` tree and each module under `modules/`) is up to date with its remote. A quick `git status -sb`/`git fetch --dry-run` per repo is enough to catch drift without altering the working tree.

### One-liner currency check

Run this from the repo root to dump the status of the main tree plus every git-backed module and attempt a dry-run fetch for each:

```
git status -sb && git fetch --dry-run && for repo in modules/*; do if [ -d "$repo/.git" ]; then echo "--- $repo ---"; git -C "$repo" status -sb; git -C "$repo" fetch --dry-run; fi; done
```

