<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://switchable-state.vercel.app/images/hero-dark.svg">
    <img src="https://switchable-state.vercel.app/images/hero.svg" alt="One state contract connected to five interchangeable adapters: Cubit, GetX, MobX, Provider and Riverpod" width="720">
  </picture>
</p>

<h1 align="center">switchable_state</h1>

<p align="center">
  One state-management contract for Flutter. Five interchangeable libraries.<br>
  <a href="https://switchable-state.vercel.app/"><b>Documentation</b></a> ·
  <a href="https://pub.dev/packages/switchable_state">pub.dev</a> ·
  <a href="example/">Example app</a>
</p>

<p align="center">
  <a href="https://github.com/EugenioTesio/switchable_state/actions/workflows/ci.yaml"><img src="https://github.com/EugenioTesio/switchable_state/actions/workflows/ci.yaml/badge.svg" alt="CI"></a>
  <a href="https://pub.dev/packages/switchable_state"><img src="https://img.shields.io/pub/v/switchable_state.svg" alt="pub package"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
</p>

Screens read state from a `StateScope` instead of passing it to each other, and every store comes from one `StateAdapter`. Swap `RiverpodStateAdapter()` for `CubitStateAdapter()`, `GetXStateAdapter()`, `MobXStateAdapter()` or `ProviderStateAdapter()` and the whole app runs on another library, with the same behaviour checked by the same tests.

## Packages

| Package | What it contains | pub.dev |
| --- | --- | --- |
| [switchable_state](packages/switchable_state) | `StateAdapter`, `StateStore`, `StateScope`, `AppState`, `StateStoreOwner` | [![pub](https://img.shields.io/pub/v/switchable_state.svg)](https://pub.dev/packages/switchable_state) |
| [switchable_state_bloc](packages/switchable_state_bloc) | `CubitStateAdapter` (flutter_bloc) | [![pub](https://img.shields.io/pub/v/switchable_state_bloc.svg)](https://pub.dev/packages/switchable_state_bloc) |
| [switchable_state_getx](packages/switchable_state_getx) | `GetXStateAdapter` (get) | [![pub](https://img.shields.io/pub/v/switchable_state_getx.svg)](https://pub.dev/packages/switchable_state_getx) |
| [switchable_state_mobx](packages/switchable_state_mobx) | `MobXStateAdapter` (mobx, flutter_mobx) | [![pub](https://img.shields.io/pub/v/switchable_state_mobx.svg)](https://pub.dev/packages/switchable_state_mobx) |
| [switchable_state_provider](packages/switchable_state_provider) | `ProviderStateAdapter` (provider) | [![pub](https://img.shields.io/pub/v/switchable_state_provider.svg)](https://pub.dev/packages/switchable_state_provider) |
| [switchable_state_riverpod](packages/switchable_state_riverpod) | `RiverpodStateAdapter` (flutter_riverpod) | [![pub](https://img.shields.io/pub/v/switchable_state_riverpod.svg)](https://pub.dev/packages/switchable_state_riverpod) |
| [switchable_state_value_notifier](packages/switchable_state_value_notifier) | `ValueNotifierStateAdapter` (Flutter only) | [![pub](https://img.shields.io/pub/v/switchable_state_value_notifier.svg)](https://pub.dev/packages/switchable_state_value_notifier) |
| [switchable_state_test](packages/switchable_state_test) | `stateStoreContract`, the conformance suite for adapters | [![pub](https://img.shields.io/pub/v/switchable_state_test.svg)](https://pub.dev/packages/switchable_state_test) |

Start with the [switchable_state README](packages/switchable_state/README.md) or the [documentation site](https://switchable-state.vercel.app/).

## Repository layout

| Path | Contents |
| --- | --- |
| `packages/` | The eight published packages |
| `example/` | A transactions app that asks which library to use at startup, then routes with go_router |
| `website/` | The documentation site (Astro Starlight), deployed to GitHub Pages |
| `.github/workflows/` | CI, the site deployment and tag-triggered publishing |
| `PUBLISHING.md` | How to release the packages and maintain the site |

## Development

This is a [pub workspace](https://dart.dev/tools/pub/workspaces): one `flutter pub get` at the root resolves every package and the example.

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze packages example
```

Run each member's tests from its folder, for example `cd packages/switchable_state_bloc && flutter test`. The CI runs all of them.

| Tests | Count | What they cover |
| --- | ---: | --- |
| `packages/switchable_state` | 62 | The scope with a fake adapter: lazy creation, keys, overrides, which stores close with which scope, groups and families, `reset`, observers, `StateStoreOwner`, `StateListener`, `asListenable`, and `update` |
| Each adapter package | 38–41 | The shared contract, then that library's own binding |
| `packages/switchable_state_test` | 34 | The contract against a `ValueNotifier` reference adapter |
| `example` | 78 | The app on all five libraries, go_router route groups, the failed-load snack bar from `StateListener`, and the README counter |

Use Flutter 3.47 or later (Dart 3.13 or later).

## License

[MIT](LICENSE)
