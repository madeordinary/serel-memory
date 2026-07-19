# Basecamp to Serel Memory compatibility

> **Historical record.** The v0.x compatibility contract described in this
> document **ended with Serel Memory 0.3.0** (July 19, 2026): the
> `.basecamp.json` anchor became `.serel-memory.json`, the `BASECAMP_HOOKS`
> fallback was removed, and `sync-upstream` stopped treating the legacy
> `gusfeliciano/basecamp` slug as an alias of the canonical repository.
> This file is kept as migration history only (it originally lived at
> `docs/basecamp-compatibility.md`); see `CHANGELOG.md` for the 0.3.0 cutover
> and downstream migration steps.

Basecamp has been renamed **Serel Memory** and its canonical GitHub home is now
`madeordinary/serel-memory`. The repository's commits, `v0.1.0` tag, release,
and MIT license continue in place.

This is a compatibility migration, not a clean break.

> **Verified July 18, 2026:** canonical and legacy Git URLs resolve to the same
> repository; `v0.1.0` and its historical release remain available; canonical
> CI and link checks pass; and both the canonical `v0.2.0` install and legacy
> redirected `v0.1.0` install were exercised successfully.

## Existing installs

Existing projects do not need an immediate migration. GitHub redirects the former
`gusfeliciano/basecamp` repository path after the transfer and rename, so old
clone URLs, provenance anchors, and `upstream` remotes continue to resolve.

New installs and reconstructed anchors use `madeordinary/serel-memory`. After a
successful fetch, an existing project may normalize its remote:

```bash
git remote set-url upstream https://github.com/madeordinary/serel-memory.git
```

The `sync-upstream` workflow treats the former and current repository slugs as
the same upstream throughout v0.x.

## Stable v0.x identifiers

Two Basecamp-era identifiers remain supported for every v0.x release:

- `.basecamp.json` remains the single provenance-anchor filename. Do not create
  a second `.serel-memory.json` file; two mutable anchors could disagree.
- `BASECAMP_HOOKS=off` continues to disable the optional hooks.
  `SEREL_MEMORY_HOOKS=off` is the preferred spelling. If either variable is
  `off`, the hooks stay disabled.

Any removal or anchor-file rename requires a separately documented migration and
will not happen silently within v0.x.

## Redirect invariant

The old-slug compatibility path depends on GitHub's repository redirect.
**Never create another repository at `gusfeliciano/basecamp`**: reusing that
name would replace the redirect and strand existing anchors and remotes.

## Post-transfer verification

After the repository is transferred and renamed:

1. Confirm the canonical clone and `npx degit madeordinary/serel-memory#v0.2.0`
   both resolve.
2. Confirm the former clone URL and the former v0.1.0 degit pin still resolve
   through GitHub's redirect.
3. Confirm the `v0.1.0` tag and release page are present at the canonical URL.
4. Confirm both CI jobs complete successfully under
   `madeordinary/serel-memory`.
5. Confirm the real canonical links pass the link check with no transition
   exclusion in `lychee.toml`.
6. Confirm CI is guarded only by the canonical repository slug after one complete
   green canonical run and successful legacy-URL checks.

The historical author attribution and MIT license remain unchanged.
