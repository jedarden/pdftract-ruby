# pdftract-ruby — Plan

## Purpose

`pdftract-ruby` is the Ruby SDK (RubyGem `pdftract`) for the `pdftract` PDF
extraction/conformance CLI (`jedarden/pdftract`, the main Rust repo). It is a
thin subprocess wrapper: it shells out to the `pdftract` binary via `Open3`,
parses its JSON/NDJSON output, and exposes 9 contract methods (`extract`,
`extract_text`, `extract_markdown`, `extract_stream`, `search`,
`get_metadata`, `hash`, `classify`, `verify_receipt`) plus 6+ typed error
classes on `Pdftract::Codegen::Client`.

The entire `lib/` tree is auto-generated from Tera templates in the main
`pdftract` repo (`templates/sdk-skeleton/ruby/`) — see `GENERATED` and
`.codegen-version` at the repo root. It is one of 8 subprocess-based SDKs
generated from the same pipeline (Node, Go, Java, .NET, Ruby, PHP, Swift,
Python-subprocess-fallback).

This file starts honest and thin, per this workspace's new-repo convention —
no retroactive full plan is fabricated for pre-existing scaffolding. It
records the current state and captures decisions going forward as ADRs.

## Current state (as of 2026-07-20, artifact-improvement audit)

- Code was generated 2026-06-01 (`.codegen-version` = `0.1.0`) and has sat
  unpushed since: **no `origin` git remote, no commits prior to this audit,
  and the repo does not exist on Forgejo (`git.ardenone.com`) or GitHub**
  (verified via API — both return "not found" as of 2026-07-20). The gem is
  **not published to RubyGems** (`rubygems.org/gems/pdftract` returns 404).
- Deferred to the "v1.1+" release wave per bead `pdftract-45vo7` (main
  `pdftract` repo's beads workspace), closed 2026-06-01 as "complete" based
  on structural code review only.
- **This audit found and fixed three shipped bugs that meant the SDK was
  100% non-functional as generated** — none had ever been caught because
  Ruby was not installed anywhere the code had been reviewed, so nothing had
  ever actually been run:
  1. `lib/pdftract.rb` used `require_relative "codegen/methods"` etc., which
     resolves to `lib/codegen/methods.rb` — a path that doesn't exist. The
     real files are at `lib/pdftract/codegen/*.rb`. Every `require "pdftract"`
     raised `LoadError` immediately; the gem could not even be loaded.
  2. `lib/pdftract/codegen/methods.rb` had a stray `private` keyword above
     `exec`/`map_error` with no `public` before the 9 contract methods, so
     the *entire public API* (`extract`, `extract_text`, ... `verify_receipt`)
     was accidentally private. Every example in this repo's own README would
     have raised `NoMethodError`.
  3. `Pdftract::Codegen::BytesSource#to_args` was `raise NotImplementedError`
     — 1 of the 3 documented `Source` types was a non-functional stub.
  - All three were manually patched here as a stopgap (see comments at each
    call site) and verified by running the gem inside a `ruby:3.2-slim`
    Docker container: `require "pdftract"` now loads, all 9 methods are
    public, `BytesSource` writes a working tempfile, and `gem build
    pdftract.gemspec` succeeds.
  - **All three bugs also exist in the source Tera templates** in the main
    `pdftract` repo (`templates/sdk-skeleton/ruby/lib/pdftract.rb.tera`,
    `.../codegen/methods.rb.tera`, `.../codegen/types.rb.tera`) — the actual
    root cause, tracked separately since that's a different repo. Patching
    only this generated copy will not survive the next codegen refresh.
- This repo has no `.beads` workspace of its own. Following the established
  pattern for its 7 sibling generated-SDK repos (`pdftract-php`,
  `pdftract-dotnet`, `pdftract-swift`, etc. — none of which have one either),
  work items for `pdftract-ruby` are tracked in the main `pdftract` repo's
  beads workspace, labeled `artifact-improvement`.
- This audit's changes were committed locally (git identity
  `github@jedarden.com` / `jedarden`) but **not pushed** — there is no
  `origin` remote to push to, since the repo has never been created on
  Forgejo or GitHub. Creating that hosting is left as an explicit follow-up
  item (see beads) rather than done silently as a side effect of this audit,
  since it's a real repo-lifecycle decision (this SDK was explicitly
  deferred to v1.1+, and the code was, until today, unverified-broken).

## ADR-001: 2026-07-20 — Containerized conformance execution as a hard gate before a generated-SDK bead can close or a publish workflow can run

### Context

`pdftract-ruby`'s entire public surface was non-functional as generated:
the gem couldn't even be `require`d (wrong `require_relative` paths), and
even fixing that, every contract method was accidentally `private`. Both
bugs live in the source Tera templates, so every one of the 8
subprocess-based SDKs generated from this pipeline (Node, Go, Java, .NET,
Ruby, PHP, Swift) is a candidate for the same class of failure — a
generator-level mistake that "looks right" in a code review (the method
names, signatures, and structure all match the contract) but breaks at
runtime in a way only actually invoking the code would reveal.

The bead that closed this SDK as done, `pdftract-45vo7`, said so explicitly
in its own retrospective: *"Ruby is not installed on the build server,
preventing local build/test verification."* It closed the bead anyway,
citing structural completeness ("all 9 contract methods exposed") as the
acceptance signal. The existing acceptance criteria for these SDK beads
already *name* a runtime check (`bundle exec rake test:conformance` must
"100% pass") but nothing enforced it — the bead was closed without it ever
running, and today's audit is the first time this code has ever executed.

Fixing today's three bugs doesn't fix the process that let all three ship
silently. Nothing currently prevents the same class of bug from being
reintroduced on the next `pdftract` template change, or from existing right
now in the other 7 sibling SDK repos.

### Decision

A generated-SDK bead (Ruby, PHP, .NET, Swift, Node, Go, Java — the 8
subprocess-based targets) may not be closed as complete, and a
`<lang>-sdk-publish` Argo Workflow may not proceed past its conformance
step, without a **containerized runtime execution** of the shared
conformance suite against that language's official Docker image — not a
structural code read. Concretely, for `pdftract-ruby` that means the
existing `bundle exec rake test:conformance` step (already specified in
`pdftract-45vo7`'s Argo template design) runs inside `ruby:3.2-slim` on
iad-ci, its pass/fail output is attached to the bead as the acceptance
evidence, and closing the bead without that evidence attached is treated as
a hygiene defect, the same class of problem as closing it with the
evidence attached but red.

This generalizes as a single parameterized `sdk-conformance-verify`
WorkflowTemplate in `jedarden/declarative-config`'s Argo Workflows (image
per language: `ruby:3.2-slim`, `node:20-slim`, `golang:1.22`, etc.), reused
by all 8 subprocess SDKs' publish workflows and available standalone for
ad hoc verification runs like the one that found today's bugs.

### Alternatives Considered

1. **Install Ruby (and PHP, .NET, Swift, Node, Go, Java toolchains) directly
   on ex44 and the lab server**, so agents/workers can run `bundle exec rake
   test` locally without going through Argo. Rejected: seven more language
   toolchains permanently installed and version-drifting on two
   general-purpose dev boxes, for a check that iad-ci's Argo Workflows
   already exist to absorb — this workspace's own CI convention is "runs on
   Argo Workflows in iad-ci," not ad hoc local toolchains.
2. **Keep structural/code-review-only verification** (the status quo).
   Rejected outright: this is exactly what produced today's bugs.
   `pdftract-45vo7` was closed on structural grounds and the SDK was
   completely unusable — `require "pdftract"` didn't even work.
3. **Add a lightweight static lint/grep check** (e.g. a script asserting
   `private`/`public` keyword balance, or a Rubocop rule flagging unexpected
   method visibility) instead of full runtime execution. Not rejected —
   filed as a companion bead, since it's cheap and would have caught bug #2
   pre-runtime. But insufficient alone: it would not have caught the
   `require_relative` path bug or the `BytesSource` stub, both of which are
   only visible by actually loading and exercising the code. Runtime
   conformance execution remains the real gate; static lint is a fast
   pre-filter on top of it.

### Consequences

- Every codegen'd SDK bead going forward needs a conformance-run link
  (Argo Workflow log or equivalent) attached before it can be closed —
  a small closure-time cost that eliminates false "done" status.
- Requires wiring the shared `sdk-conformance-verify` WorkflowTemplate,
  parameterized by language image, in `jedarden/declarative-config`
  (`k8s/iad-ci/argo-workflows/`) — start with the Ruby case since it now has
  a known-good baseline (this audit's Docker smoke test).
- `pdftract-45vo7`'s "closed/complete" status is now known stale; this ADR
  doesn't reopen it directly (tracked as a bead) but records why the
  original closure was incorrect.
- Slightly higher CI cost per SDK bead (one more container run), acceptable
  given iad-ci already exists for exactly this kind of workload and per-
  language images are standard, cacheable, off-the-shelf.
