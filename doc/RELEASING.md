# ds_print — releasing

Companion to the [README](../README.md). ds_print is not published to pub.dev;
host apps depend on it through git with a `ref`. A release is therefore just a
version bump plus a git tag, and a host picks it up by changing its `ref`.

---

## How a host resolves the package

- `ref` can be a tag, a branch or a commit SHA. Pub resolves it to one commit
  and records that SHA as `resolved-ref` in the host's `pubspec.lock`.
- `flutter pub get` reuses the locked SHA for as long as `ref` is unchanged.
  Pushing new commits here changes nothing in a host until its `ref` changes —
  or, if `ref` is a branch, until someone runs `flutter pub upgrade ds_print`.
- Pin hosts to a tag. A branch moves under you; a tag does not.

## Versioning

`version:` in `pubspec.yaml` is the source of truth. The tag is the same number
with a `v` prefix: `2.0.0` → `v2.0.0`.

From 1.0.0 on the package follows semantic versioning:

| Change | Bump | Example |
|---|---|---|
| Breaks a host: removed or renamed API, a new case on a sealed type (e.g. `DsPrintFailure`), a changed default behaviour, a new required constructor parameter (e.g. on `DsPrintTheme`) | **major** | `1.0.0` → `2.0.0` |
| Additive: new API, new optional parameter, new opt-in config | minor | `2.0.0` → `2.1.0` |
| Bug fixes with no API or behaviour change | patch | `2.0.0` → `2.0.1` |

Anything not exported from `lib/ds_print.dart` (repositories, use cases,
datasources, the native channel protocol) is internal and can change in any
release.

History: before 1.0.0 the same breaking changes bumped the **minor** number
(`0.2.0` → `0.3.0`) and additive changes and fixes bumped the patch.

## While working

Add entries under `## Unreleased` at the top of [`CHANGELOG.md`](../CHANGELOG.md)
as changes land on `main`. Leave `version:` alone until the release.

## Cutting a release

On `main`, with a clean tree:

1. `flutter analyze` and `flutter test` — clean and all passing.
2. Bump `version:` in `pubspec.yaml`.
3. Rename `## Unreleased` to `## X.Y.Z` in `CHANGELOG.md`.
4. Update `ref:` in the README's [Install](../README.md#install) snippet.
5. Commit, tag and push:

   ```bash
   git commit -am "chore: release X.Y.Z"
   git tag -a vX.Y.Z -m "vX.Y.Z"
   git push origin main
   git push origin vX.Y.Z
   ```

   If `main` only accepts pull requests, do steps 2–4 in a PR, merge it, then
   tag the merge commit:

   ```bash
   git checkout main && git pull
   git tag -a vX.Y.Z -m "vX.Y.Z"
   git push origin vX.Y.Z
   ```

6. Optional: `gh release create vX.Y.Z --title vX.Y.Z --notes "…"` for a
   GitHub Release page. Pub ignores it; it is for people.

Check the tag reached GitHub:

```bash
git ls-remote --tags origin
```

## Updating a host

Read the CHANGELOG entries between the host's current version and the new one
first — a major bump (and, before 1.0, a minor one) can need host changes. Then in the host's `pubspec.yaml`:

```yaml
dependencies:
  ds_print:
    git:
      url: https://github.com/Mustafa7Ibrahim/DsPrint.git
      ref: vX.Y.Z
```

```bash
flutter pub get
```

The host's `pubspec.lock` entry for `ds_print` should now show `ref: vX.Y.Z`,
`version: "X.Y.Z"`, and a `resolved-ref` equal to the release commit.

## Never move a pushed tag

Once a tag is pushed, treat it as permanent. Hosts that already resolved it keep
the old SHA in their lock files, so force-moving the tag means two machines can
build different code from the same `ref`. If a release is wrong, fix forward
with a new patch release.
