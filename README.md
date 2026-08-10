# Relative preset references — demo

A working Renovate preset repository that uses **relative `extends` references** to compose itself.

This repo exists to demonstrate a proposed Renovate feature. Every reference between the presets below is written as `./x`, `../x` or `/x` instead of repeating the full `github>secustor/relative-presets-demo` prefix — and each one inherits the repository and the Git tag of the preset that contains it.

> [!IMPORTANT]
> This feature is **not in a Renovate release yet**. To resolve this repository you need a Renovate build from the implementation branch: [`secustor/renovate@feat/relative-preset-paths`](https://github.com/secustor/renovate/tree/feat/relative-preset-paths). With a released Renovate, the relative entries will fail to resolve.

## The problem

A preset repository that splits its config across many files has to spell out the full address of every internal reference:

```jsonc
// default.json — the old way
{
  "extends": [
    "github>secustor/relative-presets-demo//system/registries",
    "github>secustor/relative-presets-demo//groups/aws"
  ]
}
```

Those references carry no tag, so they always resolve from the default branch. A consumer who pins the catalog to a release:

```jsonc
{ "extends": ["github>secustor/relative-presets-demo#v1.0.0"] }
```

gets `default.json` at `v1.0.0` and **every nested preset from `main`**. Pinning properly means writing `#v1.0.0` into every internal reference in every file, and rewriting all of them on every release.

## The fix

Write the reference relative to the file it lives in. It inherits the repository *and* the tag automatically:

```jsonc
// default.json — this repo
{
  "extends": ["./system/registries", "/groups/aws", "./automerge/non-breaking"]
}
```

Now `#v1.0.0` on the consumer side pins the entire tree, and releasing `v2.0.0` requires no edits to any internal reference.

## Layout

```
default.json                     extends ./system/registries, /groups/aws, ./automerge/non-breaking
├── system/
│   ├── registries.json          extends ./security          (sibling, same directory)
│   └── security.json
├── groups/
│   └── aws.json                 extends /schedules/business-hours   (from the repository root)
├── automerge/
│   ├── non-breaking.json
│   └── breaking.json            extends ../schedules/quarterly      (up one directory)
└── schedules/
    ├── business-hours.json
    └── quarterly.json
```

`automerge/breaking.json` is deliberately not pulled in by `default.json` — it is opt-in, and it is the file that demonstrates `../`.

## The three forms

| Written in | Reference | Anchored at | Resolves to |
| --- | --- | --- | --- |
| `default.json` | `./system/registries` | the file's own directory (repo root) | `github>secustor/relative-presets-demo//system/registries#<tag>` |
| `default.json` | `/groups/aws` | the repository root | `github>secustor/relative-presets-demo//groups/aws#<tag>` |
| `system/registries.json` | `./security` | `system/` | `github>secustor/relative-presets-demo//system/security#<tag>` |
| `groups/aws.json` | `/schedules/business-hours` | the repository root | `github>secustor/relative-presets-demo//schedules/business-hours#<tag>` |
| `automerge/breaking.json` | `../schedules/quarterly` | one level above `automerge/` | `github>secustor/relative-presets-demo//schedules/quarterly#<tag>` |

`<tag>` is whatever the consumer pinned. It is never written in this repository.

## Seeing tag inheritance work

Two tags exist with deliberately different content:

| Tag | `automerge/non-breaking.json` |
| --- | --- |
| `v1.0.0` | automerges minor, patch, pin and digest updates immediately |
| `v2.0.0` | the same, plus `minimumReleaseAge: "3 days"` |

A consumer pinning `#v1.0.0` (see [`examples/consumer-renovate.json`](examples/consumer-renovate.json)) resolves `automerge/non-breaking.json` **at `v1.0.0`**, without any cooldown — even though that file is reached indirectly through `default.json`. Switch the pin to `#v2.0.0` and the cooldown appears. Nothing inside this repository changes between those two outcomes.

## This repository consumes its own catalog

Besides hosting the presets, this repository contains a small app with deliberately outdated dependencies (`package.json`, `Dockerfile`) so that Renovate has something real to raise pull requests for.

Its own [`renovate.json`](renovate.json) extends the catalog at a pinned tag, exactly as any consumer would:

```jsonc
{
  "extends": ["github>secustor/relative-presets-demo#v1.0.0"],
  "schedule": ["at any time"],
  "automerge": false,
  "platformAutomerge": false
}
```

Only the first line matters for the feature. The other three are demonstration overrides: the catalog schedules pull requests for business hours and automerges non-breaking updates, which for a demo would mean either no pull requests at all or pull requests that merge themselves within seconds. Repository config wins over presets, so those three lines keep the pull requests open and visible while everything else still arrives through relative references resolved at `v1.0.0`.

Note that `renovate.json` uses the full `github>...` form. Relative references only work *inside* a preset — a repository's own configuration has no parent preset to resolve them against.

## Trying it yourself

```bash
git clone https://github.com/secustor/renovate.git
cd renovate
git checkout feat/relative-preset-paths
pnpm install

# dry run against any repo that extends this catalog
LOG_LEVEL=debug pnpm start --dry-run=full --platform=github \
  --token="$GITHUB_TOKEN" your-org/your-repo
```

In the debug log you will see each relative entry rewritten to its absolute, tag-carrying form before it is fetched.

## Rules worth knowing

- Relative references only work **inside a preset** hosted in a Git repository (GitHub, GitLab, Gitea, Forgejo, or `local>`). They do not work in a repository's own `renovate.json`, in `globalExtends`, in inherited config, or in HTTP-hosted presets.
- The tag is always inherited. Writing an explicit tag, as in `./x#v2`, is rejected.
- A relative reference addresses a preset **file**. Sub-preset keys inside a file (`./x:sub`) are not addressable, matching the existing `//path` syntax.
- A reference may not escape the repository root, and it may not carry a source prefix — `local>./x` is invalid.
- Parameters work: `./group(eslint)`. Handlebars templates are allowed inside the parameter list, but not in the path itself.
- `ignorePresets` entries may also be written relatively.

## Links

- Implementation branch: <https://github.com/secustor/renovate/tree/feat/relative-preset-paths>
- Upstream discussion: [renovatebot/renovate#24753](https://github.com/renovatebot/renovate/discussions/24753)
- Renovate preset documentation: <https://docs.renovatebot.com/config-presets/>
