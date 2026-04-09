# Templates

This directory is reserved for future template overrides.

## Current status: not loaded by forge

As of forge v2.8.0, built-in templates are baked into the forge binary at compile time via Rust `include_str!` macros. There is no runtime lookup path from any of the oh-my-forge install locations to these templates, so files you drop here are **not** picked up by the forge runtime.

Evidence:

- `crates/forge_domain/src/tools/result.rs` and similar files use `include_str!("../../../../templates/forge-partial-tool-error-reflection.md")` to bake templates into the binary.
- `ForgeTemplateService::register_template` at `crates/forge_services/src/template.rs:80` exists but is not invoked from a user-configurable location in the CLI path.

## Why keep this directory?

1. If forge adds user-template overrides in a future release, oh-my-forge will ship overrides here and the installer will copy them to the right path.
2. The directory's presence is referenced by `catalog-manifest.json` for forward compatibility.
3. Contributors can still use this directory to stash templates for reference or for manual copy into the forgecode source when experimenting with binary rebuilds.

## What to do if you need a template override today

Three real options:

1. **Fork forgecode** and rebuild — only for people shipping forge binaries.
2. **Replace the behavior in a skill** — skills are the right layer for most customization.
3. **File an issue upstream** requesting user-template-override support.
