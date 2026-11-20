# Publishing switchable_state

This guide covers the documentation home page and releasing the seven packages to pub.dev.

## The home page

### Why Astro Starlight

These are the options for a free, public documentation site for a Flutter package, and how the five supported libraries do it:

| Tool | Used by | Verdict for this project |
| --- | --- | --- |
| **Astro Starlight** | bloclibrary.dev | **Chosen.** Markdown/MDX pages, built-in search, light and dark themes and optimised images. It builds to static files, so any static host can serve it, and it lives in this repository. |
| Docusaurus | riverpod.dev, mobx.netlify.app | Proven, but heavier React tooling. |
| docs.page (Invertase) | Melos, flutter_stripe | No build step, but you get less control over the look, and the site depends on a third-party service. |
| Jaspr / jaspr_content | dart.dev, docs.flutter.dev | Written in Dart, but jaspr_content is still pre-1.0, with fewer ready-made docs features. |
| VitePress, MkDocs Material | | VitePress 2 is still in alpha; MkDocs Material is in maintenance mode. |
| README + API docs only | provider, get | The lowest effort, but no guides, search or visuals. |

The site is hosted on **Vercel** at **https://switchable-state.vercel.app/**, and every pubspec's `homepage` and `documentation` point to it. A GitHub Pages workflow is kept as an alternative; see below.

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

**Vercel (current host).** The project `switchable-state` serves the site at the root of `https://switchable-state.vercel.app/`, using `website/vercel.json`. Deploy from your machine with the Vercel CLI:

```sh
cd website
npx vercel deploy --prod
```

To deploy on every push instead, run `npx vercel git connect` inside `website/`. Alternatively, import the GitHub repository in the Vercel dashboard and set its **Root Directory** to `website`.

**GitHub Pages (alternative).** `.github/workflows/pages.yaml` builds the site for `https://eugeniotesio.github.io/switchable_state/`, setting `SITE_URL` and `BASE_PATH`, and deploys it on pushes to `main` that touch `website/`. It needs GitHub Actions available on the account, plus **Settings → Pages → Source: GitHub Actions**. If you switch back, update the URLs in the pubspecs and READMEs.

The site address comes from two environment variables read by `astro.config.mjs`: `SITE_URL` (default `https://switchable-state.vercel.app`) and `BASE_PATH` (default `/`). Links between pages are relative, so the same content works at either address.

### A custom domain (optional)

1. Buy a domain and add it in the Vercel dashboard under **Project → Settings → Domains**, for example `docs.yourdomain.dev`. Vercel shows the DNS record to create and issues the HTTPS certificate.
2. Build with that address: set the project's `SITE_URL` environment variable to `https://docs.yourdomain.dev`, or change the default in `astro.config.mjs`.
3. Update the absolute links in the READMEs and pubspecs.
4. With your own domain you can create a pub.dev **verified publisher**: verify the domain in Google Search Console, create the publisher on pub.dev, and transfer the packages to it. `vercel.app` and `github.io` addresses can't be verified, because you can't add DNS records to them.

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
