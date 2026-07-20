# Shipped bugs found during 2026-07-20 artifact-improvement audit

Three bugs made the generated SDK 100% non-functional; all three were
manually patched in this repo as a stopgap (see inline `NOTE:` comments at
each site) and verified end-to-end inside `ruby:3.2-slim`. **The real fix
still needs to land in the source Tera templates** in the main `pdftract`
repo, or these regress on the next codegen refresh:

1. `lib/pdftract.rb` — `require_relative "codegen/methods"` (and
   `errors`/`types`) resolved to the nonexistent `lib/codegen/*.rb` instead
   of `lib/pdftract/codegen/*.rb`. `require "pdftract"` raised `LoadError`.
   Template: `templates/sdk-skeleton/ruby/lib/pdftract.rb.tera` (pdftract repo).
2. `lib/pdftract/codegen/methods.rb` — a stray `private` above `exec`/
   `map_error` had no matching `public` before the 9 contract methods, so
   the entire client API was accidentally private.
   Template: `templates/sdk-skeleton/ruby/lib/pdftract/codegen/methods.rb.tera`.
3. `lib/pdftract/codegen/types.rb` — `BytesSource#to_args` was
   `raise NotImplementedError` (a stub), 1 of 3 documented `Source` types.
   Template: `templates/sdk-skeleton/ruby/lib/pdftract/codegen/types.rb.tera`.

See `docs/plan/plan.md` ADR-001 for the systemic fix (containerized
conformance execution as a bead-closure/publish gate) intended to prevent
this class of bug from shipping silently again.
