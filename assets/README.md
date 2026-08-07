# Asset ownership and preservation

`asset_classification.json` is the authoritative lifecycle inventory for `assets/`.
Categories use the longest matching path prefix, so a specific generated or legacy
folder can override its broader domain.

- `active`: runtime or actively maintained candidate material.
- `candidate_preserved`: an iteration retained for review or later reuse.
- `legacy_preserved`: a compatibility/source iteration that must not be removed merely
  because no current scene references it.
- `required`: licensing or attribution material that stays with the repository.

Run `python3 tools/audit_assets.py` for a read-only inventory. The audit reports direct
literal references as a navigation hint; it never treats zero direct references as
permission to delete an asset.
