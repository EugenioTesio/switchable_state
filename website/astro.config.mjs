// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// Vercel serves the site at the root. GitHub Pages serves it under the
// repository name, so its workflow sets SITE_URL and BASE_PATH.
const site = process.env.SITE_URL ?? 'https://switchable-state.vercel.app';
const base = process.env.BASE_PATH ?? '/';
const og = `${site}${base.replace(/\/$/, '')}/og.png`;
const repo = 'https://github.com/EugenioTesio/switchable_state';

// https://astro.build/config
export default defineConfig({
	site,
	base,
	integrations: [
		starlight({
			title: 'switchable_state',
			description:
				'One state-management contract for Flutter with five interchangeable libraries: Cubit, GetX, MobX, Provider and Riverpod.',
			logo: { src: './src/assets/logo.svg' },
			favicon: '/favicon.svg',
			customCss: ['./src/styles/theme.css'],
			social: [
				{ icon: 'github', label: 'GitHub', href: repo },
				{ icon: 'external', label: 'pub.dev', href: 'https://pub.dev/packages/switchable_state' },
			],
			editLink: { baseUrl: `${repo}/edit/main/website/` },
			lastUpdated: false,
			head: [
				{ tag: 'meta', attrs: { property: 'og:image', content: og } },
				{ tag: 'meta', attrs: { property: 'og:image:width', content: '1200' } },
				{ tag: 'meta', attrs: { property: 'og:image:height', content: '630' } },
				{ tag: 'meta', attrs: { name: 'twitter:card', content: 'summary_large_image' } },
				{ tag: 'meta', attrs: { name: 'twitter:image', content: og } },
			],
			sidebar: [
				{ label: 'Getting started', slug: 'getting-started' },
				{
					label: 'Concepts',
					items: [
						{ label: 'The contract', slug: 'concepts/contract' },
						{ label: 'Who owns a store', slug: 'concepts/ownership' },
						{ label: 'Rebuilding with watch and select', slug: 'concepts/rebuilds' },
					],
				},
				{
					label: 'Guides',
					items: [
						{ label: 'Routes with go_router', slug: 'guides/go-router' },
						{ label: 'Testing', slug: 'guides/testing' },
						{ label: 'Write your own adapter', slug: 'guides/custom-adapter' },
					],
				},
				{
					label: 'Adapters',
					items: [
						{ label: 'Cubit (flutter_bloc)', slug: 'adapters/bloc' },
						{ label: 'GetX', slug: 'adapters/getx' },
						{ label: 'MobX', slug: 'adapters/mobx' },
						{ label: 'Provider', slug: 'adapters/provider' },
						{ label: 'Riverpod', slug: 'adapters/riverpod' },
					],
				},
				{
					label: 'Reference',
					items: [
						{ label: 'Comparison with the five libraries', slug: 'reference/comparison' },
						{ label: 'Packages on pub.dev', link: 'https://pub.dev/packages?q=switchable_state', attrs: { target: '_blank' } },
						{ label: 'API reference', link: 'https://pub.dev/documentation/switchable_state/latest/', attrs: { target: '_blank' } },
						{ label: 'Changelog', link: `${repo}/blob/main/packages/switchable_state/CHANGELOG.md`, attrs: { target: '_blank' } },
					],
				},
			],
		}),
	],
});
