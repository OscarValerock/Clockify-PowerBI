# Clockify Custom Connector — Modernization Spec

Working doc for the `feat/connector-modernize` branch. A second agent executes
this in the Power Query SDK window; the repo owner drives the build/test loop.

## Context

`OscarValerock/Clockify-PowerBI` is the free-tier companion to the paid bibb.pro
Clockify Power BI template. It ships a custom Power Query connector
(`Clockify/Clockify.pq` → `Clockify.mez`) and, currently, a `.pbit` template.

Two problems justify this work:

1. **Data-loss bug.** Only `Clockify.TimeEntries` paginates. `Workspaces`, `Users`,
   `User Groups`, `Projects`, `Tasks`, `Clients`, `Tags`, and both Custom Fields
   functions each fire a single request with `page-size=5000`. Clockify defaults
   list endpoints to 50 and caps most non-time-entry endpoints well below 5000,
   and it caps **silently** — so any workspace past the cap loses rows with no
   error. Shipping since 2022.
2. **Dead toolchain.** The build is a legacy Visual Studio `.mproj` with a
   hand-rolled `CodeTaskFactory` zip task. `.vscode/settings.json` is already in
   SDK mode but points at legacy paths, and `resources.resx` still holds the
   project-wizard boilerplate (`"this is my long string"`, `Color1 = Blue`,
   base64 placeholder blocks).

Outcome: a correct, paginating connector on the current VS Code Power Query SDK,
consolidated to one clean entry point, `.pbit` removed so the free tier is
connector-only.

## Decisions (locked with the repo owner)

| Decision | Choice |
|---|---|
| Entry point | **Consolidate** to a single `Clockify.Contents(optional url)` returning the navigation table. The 10 individual `Clockify.X()` shared functions become `local`. **Breaks existing users' reports** on upgrade — call it out in release notes. |
| Build system | **Migrate** to the current VS Code Power Query SDK (`Clockify.proj` + regenerated `.vscode/settings.json` + `pqtest` settings). Remove `.mproj` and `.sln`. |
| Incremental refresh | **Out of scope.** No `RangeStart`/`RangeEnd`. Paid-template differentiator. |
| Reports API (`reports.api.clockify.me`) | **Out of scope.** Per-user time-entries loop stays. Fast bulk pull is a paid feature. |
| `Beta` flag | Flip `true` → `false`; call this **1.0**. |
| `.pbit` in repo | **Delete** `Clockify-PBI-Template-PBIT/`. Remove the template sections from README. |
| Branch | `feat/connector-modernize` (checked out). Owner opens the PR. |
| Self-hosted | Optional `url` parameter on `Clockify.Contents`. |

## TASK 1 (do this first): stand up the Power Query SDK

**Do not touch any connector code until this is done and verified.**

Owner works in a **separate single-folder VS Code window** opened on
**`C:\Users\oscar\Repos\Clockify-PowerBI\Clockify`** — SDK settings use bare
`${workspaceFolder}`, which is ambiguous in a multi-root workspace.

### What actually happened (2026-09-06)

- Extension `PowerQuery.vscode-powerquery-sdk` **0.7.1** was already installed
  (latest on the Marketplace; the "2.x" in an earlier draft was wrong). Language
  extension `PowerQuery.vscode-powerquery` 1.0.0. No update needed.
- `PowerQuery.SdkTools` NuGet **2.155.2** downloaded fine after one retry
  (`PQTest.exe` under the extension's `.nuget/`).
- **`Set up workspace` is a no-op here** — it only fills in
  `defaultQueryFile` / `defaultExtension` in `.vscode/settings.json`, and the
  legacy config already had both. Not a failure; nothing to configure.
- **v0.7.1 has no `.proj` scaffolding and needs none.** Build runs
  `MakePQX.exe compile <folder>` → zips the one `.pq` + PNGs + `resources.resx`
  into `bin\AnyCPU\Debug\Clockify.mez`. It only falls back to legacy MSBuild if a
  `.mproj`/`.proj` exists **and** `msbuild` is on PATH — and there is **no
  msbuild on PATH** on this machine, so MakePQX is always used.
- The SDK panel ("Power Query SDK" tree in the Explorer sidebar) only shows
  credential actions + **Evaluate current file** + **Run TestConnection**. There
  is **no Build button**; build is **Ctrl+Shift+B** (task `powerquery: compile`)
  and also runs automatically before an evaluate.
- **Mishap:** `Create an extension project` got clicked and overwrote
  `Clockify.pq`, `Clockify.query.pq`, `resources.resx`, all 8 PNGs, and
  `.vscode/settings.json` with the hello-world template. All restored from git
  (`git checkout -- ...`); the real 422-line connector was safe in commit
  `5b65308`. **Do not click "Create an extension project" again.**
- **Kept from the scaffold:** `Clockify/Clockify.proj` — the modern MSBuild
  project (`ZipDirectory`, no `CodeTaskFactory`). Currently cosmetic (MakePQX
  ignores it without msbuild) but it's the clean build file for Fabric CI /
  future msbuild use, and it replaces `Clockify.mproj`.

### Remaining TASK 1 steps

1. **Ctrl+Shift+B** → `powerquery: compile` → rebuild `bin\AnyCPU\Debug\Clockify.mez`
   from the *restored* real connector.
2. SDK panel → **Set credential** → kind **Clockify** → **Key** → paste a real
   Clockify API key (needs a built `.mez` first, or the kind list is empty).
3. Open `Clockify.query.pq` (make it the active tab) → **Evaluate current file**
   → confirm it returns the nav table **with the connector as it is today**.
   Known-good baseline; the rewrite is diffed against it.

Only when 1–3 pass, commit on `feat/connector-modernize`
(`chore: migrate to VS Code Power Query SDK`; adds `Clockify.proj`, removes
`Clockify.mproj` + `Clockify.sln`) and start TASK 2.

The executing agent cannot build or run `pqtest` (no SDK/.NET on the main
machine). Working loop for every subsequent change: agent writes code → owner
builds + evaluates in the SDK window → pastes results/errors → agent iterates.
Final check is Power BI Desktop.

## TASK 2 onward: the connector rewrite

## Target `Clockify.pq` structure

Single section document. Only `Clockify.Contents` is `shared`; everything else
`local`.

```
section Clockify;

DefaultBaseUrl = "https://api.clockify.me/api/v1";
DefaultPageSize = 200;          // safe for every list endpoint

// ---------- entry point ----------
[DataSource.Kind="Clockify", Publish="Clockify.Publish"]
shared Clockify.Contents = Value.ReplaceType(ClockifyImpl, ClockifyType);

ClockifyType = type function (
    optional url as (type text meta [
        Documentation.FieldCaption = "API URL",
        Documentation.FieldDescription = "Leave blank for the Clockify cloud. For a self-hosted Clockify, enter the full API base URL, e.g. https://clockify.example.com/api/v1",
        Documentation.SampleValues = { DefaultBaseUrl }
    ]))
    as table meta [ Documentation.Name = "Clockify" ];

ClockifyImpl = (optional url as text) as table =>
    let base = if url = null or url = "" then DefaultBaseUrl else url
    in NavTable(base);
```

### Navigation table

Reuse the existing `NavTable.to` helper (rename to `Table.ToNavigationTable` to
match the MS samples, or keep the name — cosmetic). Entities, unchanged from
today: Workspaces, Users, User Groups, Projects, Tasks, Time Entries, Clients,
Tags, Custom Fields (Workspace), Custom Fields (Project).

### Request + pagination helpers (the core of the fix)

```
Clockify.Request = (base as text, path as text, optional query as record) as record =>
    let
        key = Extension.CurrentCredential()[Key],
        resp = Web.Contents(base, [
            RelativePath = path,
            Query = query ?? [],
            Headers = [ #"X-Api-Key" = key ],
            ManualStatusHandling = {400, 401, 403, 404, 429, 500, 502, 503},
            ManualCredentials = true
        ]),
        buf = Binary.Buffer(resp),
        m = Value.Metadata(resp)
    in
        [ Status = m[Response.Status], Headers = try m[Headers] otherwise [], Body = buf ];

// exponential backoff on 429: 1s, 2s, 4s, 8s, 16s
Clockify.RequestRetry = (base, path, query) =>
    let go = (n as number) as record =>
        let r = Clockify.Request(base, path, query) in
        if r[Status] = 429 and n < 5
        then Function.InvokeAfter(() => @go(n + 1), #duration(0,0,0, Number.Power(2, n)))
        else r
    in go(0);

// loop pages until the Last-Page response header is "true" (or an empty page)
Clockify.GetList = (base as text, path as text, optional query as record) as list =>
    let
        page = (n as number, acc as list) as list =>
            let
                q = Record.Combine({ query ?? [], [ #"page" = Text.From(n), #"page-size" = Text.From(DefaultPageSize) ] }),
                r = Clockify.RequestRetry(base, path, q),
                _ = if r[Status] >= 400 then error Clockify.Error(r) else null,
                items = let b = Json.Document(r[Body]) in if b is list then b else {},
                last = try Text.Lower(Record.FieldOrDefault(r[Headers], "Last-Page", "true")) = "true"
                       otherwise List.Count(items) < DefaultPageSize,
                acc2 = acc & items
            in
                if last or List.IsEmpty(items) then acc2 else @page(n + 1, acc2)
    in
        page(1, {});

Clockify.Error = (r as record) as record =>
    let body = try Text.FromBinary(r[Body]) otherwise "" in
    [ Reason = "DataSource.Error",
      Message =
        if r[Status] = 401 then "Clockify rejected the API key (401). Check your saved credential."
        else if r[Status] = 403 then "Clockify denied access (403). The key may lack permission."
        else if r[Status] = 429 then "Clockify rate limit hit (429); retries exhausted."
        else "Clockify request failed (" & Text.From(r[Status]) & "). " & body,
      Detail = body ];
```

> **Verify during implementation:** reading a response header via
> `Value.Metadata(...)[Headers]` after `Binary.Buffer` behaves differently across
> mashup engine versions. If `Last-Page` doesn't come through, the
> `List.Count(items) < DefaultPageSize` fallback already covers correctness — the
> header is only an optimization to skip the final empty request.

### Entity functions

Each collapses to: get workspace ids → `Table.AddColumn(... each Clockify.GetList(base, "/workspaces/" & [Workspace ID] & "/<entity>"))` → `Table.ExpandListColumn` → `Table.ExpandRecordColumn`.

- **Keep every output column name identical to the current connector** (see
  `Clockify.pq` lines 44–372 for the exact `Table.ExpandRecordColumn` name
  lists). One breaking change is enough; no gratuitous column churn.
- `Time Entries` keeps its per-user `List.Generate` loop but swaps the manual
  `page-size=5000` loop for `Clockify.GetList` per user.
- `Workspaces` is fetched by several downstream functions; that redundancy exists
  today. Leave it; note it in the README "known limitations".

### DataSource.Kind / Publish

```
Clockify = [
    TestConnection = (dataSourcePath) => { "Clockify.Contents" },
    Authentication = [ Key = [ KeyLabel = "Clockify API Key" ] ],
    Label = Extension.LoadString("DataSourceLabel")
];

Clockify.Publish = [
    Beta = false,
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://www.bibb.pro/post/clockify-power-bi-template",
    SourceImage = Clockify.Icons,
    SourceTypeImage = Clockify.Icons
];
```

> **Verify:** with an *optional* `url` parameter, Power Query does not include it
> in the data-source path by default, so one credential is shared across cloud +
> any self-hosted URL. Acceptable here. For per-URL credentials, `url` must become
> required or be surfaced through the path function, with `TestConnection`
> updated to `{ "Clockify.Contents", url }`.

## resources.resx

Rewrite from the SDK scaffold's fresh `resources.resx`. Keep only:

| Key | Value |
|---|---|
| `DataSourceLabel` | `Clockify` |
| `ButtonTitle` | `Clockify` |
| `ButtonHelp` | `Connect to Clockify time tracking data` |

Delete `Name1`, `Color1`, and the commented base64 placeholder `<data>` blocks.

## Repo cleanup

- Delete `Clockify-PBI-Template-PBIT/` (the `.pbit`).
- Delete root `Clockify.sln`, `Clockify/Clockify.mproj`.
- Downloadable `.mez` stays tracked at the **repo root**
  (`C:\Users\oscar\Repos\Clockify-PowerBI\Clockify.mez`), where the README links
  it as `raw/master/Clockify.mez`. The SDK builds to `Clockify/bin/...`; the
  owner copies the built `.mez` to the repo root manually at release time. Do not
  delete the root `.mez`.
- `README.md`: remove "2. Clockify template" and "2.1 self-hosted template";
  rewrite the connector section for the single `Clockify.Contents` entry point +
  optional URL field; drop the stale "Detailed Report Start year" text; keep the
  store.bibb.pro and blog links.
- Add release notes: "1.0 — consolidated to a single `Clockify.Contents` entry
  point (breaking: re-connect through the navigator), fixed pagination on all
  list endpoints, added self-hosted URL support, 429 retry, migrated to the VS
  Code Power Query SDK. `.pbit` removed."

## Out of scope

Incremental refresh, Reports API / detailed-report pull, OAuth, code signing,
connector certification, semantic-model/report content, the paid template.

## Verification

1. **SDK build** → `.mez` produced, no errors.
2. **Evaluate `Clockify.query.pq`** (`Clockify.Contents()`): nav table with 10
   entities; each expands to data.
3. **Pagination proof**: point at a workspace with >200 of something
   (projects/tasks/tags). Row count must exceed 200 and match the Clockify UI
   count. PWC (65 projects, ~199 tasks) is borderline; the "Sample data"
   workspace or a synthetic top-up may be needed to cross 200 cleanly.
4. **Self-hosted param**: `Clockify.Contents("https://api.clockify.me/api/v1")`
   equals `Clockify.Contents()`.
5. **Error path**: bad credential → clean 401 message, not a raw mashup dump.
6. **Power BI Desktop**: copy the `.mez` to
   `Documents\Power BI Desktop\Custom Connectors\`, enable "allow any extension",
   Get Data → Clockify → connect with key → load a couple of tables → refresh.

## Reference: current connector

`Clockify/Clockify.pq` (422 lines) — read it for the exact endpoint paths and the
`Table.ExpandRecordColumn` column-name lists to preserve. `Clockify.query.pq` is
the test harness. `Clockify.mproj` is the toolchain being replaced.
