# Publishing switchable_state

This guide covers the documentation home page and releasing the seven packages to pub.dev.

## The home page

### Why Astro Starlight on GitHub Pages

These are the options for a free, public documentation site for a Flutter package, and how the five supported libraries do it:

| Tool | Used by | Verdict for this project |
| --- | --- | --- |
| **Astro Starlight** + GitHub Pages | bloclibrary.dev | **Chosen.** Markdown/MDX pages, built-in search, light and dark themes, optimised images, and an official GitHub Pages action. Free, and it lives in this repository. |
| Docusaurus | riverpod.dev, mobx.netlify.app | Proven, but heavier React tooling. |
| docs.page (Invertase) | Melos, flutter_stripe | No build step, but you get less control over the look, and the site depends on a third-party service. |
| Jaspr / jaspr_content | dart.dev, docs.flutter.dev | Written in Dart, but jaspr_content is still pre-1.0, with fewer ready-made docs features. |
| VitePress, MkDocs Material | | VitePress 2 is still in alpha; MkDocs Material is in maintenance mode. |
| README + API docs only | provider, get | The lowest effort, but no guides, search or visuals. |

The site is published at **https://eugeniotesio.github.io/switchable_state/**, and every pubspec's `homepage` and `documentation` point to it.

### Edit and preview it

The site lives in `website/` (Node 22 or later):

```sh
cd website
npm ci
npm run dev       # live preview at http://localhost:4321/switchable_state/
npm run build     # production build into website/dist
```

| Path | Contents |
| --- | --- |
| `src/content/docs/` | The pages, in Markdown or MDX. The file path is the URL. |
| `astro.config.mjs` | Site URL, base path, sidebar, social links and `og:image` tags |
| `src/styles/theme.css` | Brand colours, the gallery and diagram styles |
| `src/assets/diagrams/` | Hand-drawn SVG diagrams. They're inlined, so they follow the light/dark toggle. |
| `screenshots/` | Raw simulator screenshots of the example app |
| `scripts/hero.mjs`, `scripts/screens.mjs` | Generate the animated hero, the framed phones, the trio and `public/og.png` (`npm run images`) |

To refresh the screenshots, run the example on an iPhone simulator, save new captures over `website/screenshots/*.png` (for example with `xcrun simctl io booted screenshot transactions_cubit.png`), and run `npm run images`. Copy two of them, resized, into `packages/switchable_state/screenshots/` for pub.dev.

### How it deploys

`.github/workflows/pages.yaml` builds the site with `withastro/action` and deploys it with `actions/deploy-pages` on every push to `main` that touches `website/`. You can also run it by hand from the Actions tab.

One-time setup: in the repository, go to **Settings → Pages → Build and deployment → Source** and select **GitHub Actions**.

### A custom domain (optional)

1. Buy a domain and add a `CNAME` DNS record pointing `docs.yourdomain.dev` to `eugeniotesio.github.io`.
2. Add `website/public/CNAME` containing `docs.yourdomain.dev`, then enter the same domain in **Settings → Pages → Custom domain** and tick **Enforce HTTPS**.
3. In `website/astro.config.mjs`, set `site` to `https://docs.yourdomain.dev` and remove `base`. Update the absolute links in the pages, READMEs and pubspecs.
4. With your own domain you can create a pub.dev **verified publisher**: verify the domain in Google Search Console, create the publisher on pub.dev, and transfer the packages to it. `github.io` addresses can't be verified.

## Releasing to pub.dev

Seven packages are published from `packages/`, all at the same version:

| Order | Package |
| ---: | --- |
| 1 | `switchable_state` |
| 2 | `switchable_state_test` (the adapters' tests depend on it) |
| 3 | `switchable_state_bloc`, `switchable_state_getx`, `switchable_state_mobx`, `switchable_state_provider`, `switchable_state_riverpod` |

### Before every release

```sh
flutter pub get
dart format --set-exit-if-changed packages example
flutter analyze packages example
for d in packages/* example; do (cd "$d" && flutter test) || break; done
for d in packages/*; do (cd "$d" && dart pub publish --dry-run) || break; done
```

Every dry run must report `Package has 0 warnings.` The CI runs the same checks, plus an analysis with the lowest allowed dependency versions.

### The first release (manual)

pub.dev only allows automated publishing for packages that already exist, so the first version of each package is published from your machine. A published version can't be deleted, only retracted within 7 days.

```sh
cd packages/switchable_state && dart pub publish
```

```sh
cd packages/switchable_state_test && dart pub publish
```

```sh
cd packages/switchable_state_bloc && dart pub publish
```

Repeat for `switchable_state_getx`, `switchable_state_mobx`, `switchable_state_provider` and `switchable_state_riverpod`. The first `dart pub publish` opens a browser to sign in with your Google account.

### Turn on automated publishing

For each package, open `https://pub.dev/packages/<package>/admin`, and under **Automated publishing**:

- Enable **publishing from GitHub Actions**.
- **Repository:** `EugenioTesio/switchable_state`
- **Tag pattern:** `<package>-v{{version}}`, for example `switchable_state_riverpod-v{{version}}`
- Optionally tick **Require GitHub Actions environment** and enter `pub.dev`. Then in GitHub, under **Settings → Environments → pub.dev**, add yourself as a required reviewer, so every publish waits for your approval.

### Later releases

1. Bump `version` in each package you release, and add a `## <version>` entry to its `CHANGELOG.md`. Keep `switchable_state: ^x.y.z` constraints in the adapters in step with the core.
2. Commit, then push one tag per package, core first:

   ```sh
   git tag switchable_state-v0.2.0 && git push origin switchable_state-v0.2.0
   ```

   ```sh
   git tag switchable_state_riverpod-v0.2.0 && git push origin switchable_state_riverpod-v0.2.0
   ```

`.github/workflows/publish.yaml` matches the tag, resolves `packages/{package}` from its prefix, validates the package and publishes it with a short-lived OIDC token. No pub.dev credentials are stored in GitHub.
