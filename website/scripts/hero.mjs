// Generates the animated hero illustration in light and dark variants:
// one StateStore contract with five adapter "cartridges" around it. The
// active adapter cycles every two seconds; reduced motion shows Cubit only.
//
// Run with `npm run images` (see package.json). Outputs:
//   src/assets/hero-light.svg, src/assets/hero-dark.svg  (site hero)
//   public/images/hero.svg, public/images/hero-dark.svg   (READMEs)
import { mkdirSync, writeFileSync } from 'node:fs';

const W = 720;
const H = 470;
const CX = 360;
const CY = 235;

const adapters = [
	{ name: 'Cubit', native: 'Cubit<S>', letter: 'C', color: '#6366f1', angle: 270 },
	{ name: 'GetX', native: 'Rx<S>', letter: 'G', color: '#e0812f', angle: 342 },
	{ name: 'MobX', native: 'Observable<S>', letter: 'M', color: '#e2486f', angle: 54 },
	{ name: 'Provider', native: 'ChangeNotifier', letter: 'P', color: '#0ea5c6', angle: 126 },
	{ name: 'Riverpod', native: 'Notifier<S>', letter: 'R', color: '#8b5cf6', angle: 198 },
];

const themes = {
	light: {
		ink: '#0f2b28',
		muted: '#5b6b69',
		surface: '#ffffff',
		border: '#cfe0dc',
		grid: '#16665c',
		gridOpacity: 0.09,
		accent: '#16665c',
		accentSoft: '#1f9e8c',
		glow: '#3cc7b0',
		glowOpacity: 0.28,
		chipBg: '#e8f4f1',
		shadow: '#0f2b28',
		shadowOpacity: 0.12,
	},
	dark: {
		ink: '#e6f2ef',
		muted: '#9bb3ae',
		surface: '#13201e',
		border: '#2c4440',
		grid: '#3cc7b0',
		gridOpacity: 0.1,
		accent: '#3cc7b0',
		accentSoft: '#3cc7b0',
		glow: '#1f9e8c',
		glowOpacity: 0.38,
		chipBg: '#1c302d',
		shadow: '#000000',
		shadowOpacity: 0.45,
	},
};

const FONT = `Inter, ui-sans-serif, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif`;
const MONO = `'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, monospace`;

const HUB_W = 236;
const HUB_H = 150;
const CART_W = 164;
const CART_H = 60;
const RX = 274;
const RY = 182;

function position(angle) {
	const r = (angle * Math.PI) / 180;
	return { x: CX + RX * Math.cos(r), y: CY + RY * Math.sin(r) };
}

// The point where the line from the hub centre to (x, y) leaves a w x h box
// centred on (cx, cy).
function edge(cx, cy, w, h, x, y) {
	const dx = x - cx;
	const dy = y - cy;
	const scale = 1 / Math.max(Math.abs(dx) / (w / 2), Math.abs(dy) / (h / 2));
	return { x: cx + dx * scale, y: cy + dy * scale };
}

const f = (n) => Math.round(n * 10) / 10;

function svg(t, { still = -1 } = {}) {
	const delay = (i) => (i === 0 ? 0 : 2 * i - 10);

	const connectors = adapters
		.map((a, i) => {
			const p = position(a.angle);
			const from = edge(CX, CY, HUB_W + 8, HUB_H + 8, p.x, p.y);
			const to = edge(p.x, p.y, CART_W + 8, CART_H + 8, CX, CY);
			const d = `M${f(from.x)} ${f(from.y)} L${f(to.x)} ${f(to.y)}`;
			return `
    <path d="${d}" class="wire" />
    <g class="on${i === still ? ' still' : ''}" style="animation-delay:${delay(i)}s">
      <path d="${d}" stroke="${a.color}" stroke-width="3" stroke-linecap="round" opacity="0.35" />
      <path d="${d}" stroke="${a.color}" class="flow" />
    </g>
    <circle cx="${f(from.x)}" cy="${f(from.y)}" r="4" class="pin" />
    <circle cx="${f(to.x)}" cy="${f(to.y)}" r="4" class="pin" />`;
		})
		.join('');

	const cartridges = adapters
		.map((a, i) => {
			const p = position(a.angle);
			const x = p.x - CART_W / 2;
			const y = p.y - CART_H / 2;
			return `
    <g>
      <rect x="${f(x - 5)}" y="${f(y - 5)}" width="${CART_W + 10}" height="${CART_H + 10}" rx="19"
        fill="none" stroke="${a.color}" stroke-width="2.5" class="on${i === still ? ' still' : ''}" style="animation-delay:${delay(i)}s" filter="url(#glow)" />
      <rect x="${f(x)}" y="${f(y)}" width="${CART_W}" height="${CART_H}" rx="14" class="card" filter="url(#shadow)" />
      <rect x="${f(x + 12)}" y="${f(y + 15)}" width="30" height="30" rx="8" fill="${a.color}" />
      <text x="${f(x + 27)}" y="${f(y + 35.5)}" text-anchor="middle" class="letter">${a.letter}</text>
      <text x="${f(x + 52)}" y="${f(y + 27)}" class="name">${a.name}</text>
      <text x="${f(x + 52)}" y="${f(y + 45)}" class="native">${a.native.replace('<', '&lt;').replace('>', '&gt;')}</text>
    </g>`;
		})
		.join('');

	const hubX = CX - HUB_W / 2;
	const hubY = CY - HUB_H / 2;
	const members = [
		['value', 'replace', 'update'],
		['watch', 'select', 'close'],
	];
	const chips = members
		.map((row, r) =>
			row
				.map((m, c) => {
					const cw = 62;
					const x = hubX + 18 + c * (cw + 6);
					const y = hubY + 50 + r * 30;
					return `<rect x="${f(x)}" y="${f(y)}" width="${cw}" height="22" rx="11" class="chip" /><text x="${f(x + cw / 2)}" y="${f(y + 15)}" text-anchor="middle" class="member">${m}</text>`;
				})
				.join(''),
		)
		.join('\n      ');

	const activeNames = adapters
		.map(
			(a, i) =>
				`<text x="${f(hubX + 92)}" y="${f(hubY + HUB_H - 17)}" class="active on${i === still ? ' still' : ''}" fill="${a.color}" style="animation-delay:${delay(i)}s">${a.name}</text>`,
		)
		.join('\n      ');

	return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-labelledby="title desc">
  <title id="title">switchable_state</title>
  <desc id="desc">One StateStore contract in the centre, wired to five interchangeable adapters: Cubit, GetX, MobX, Provider and Riverpod. Each adapter lights up in turn.</desc>
  <defs>
    <pattern id="dots" width="22" height="22" patternUnits="userSpaceOnUse">
      <circle cx="2" cy="2" r="1.3" fill="${t.grid}" opacity="${t.gridOpacity}" />
    </pattern>
    <radialGradient id="halo" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="${t.glow}" stop-opacity="${t.glowOpacity}" />
      <stop offset="100%" stop-color="${t.glow}" stop-opacity="0" />
    </radialGradient>
    <linearGradient id="hubBorder" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="${t.accentSoft}" />
      <stop offset="100%" stop-color="${t.accent}" />
    </linearGradient>
    <radialGradient id="fade" cx="50%" cy="50%" r="55%">
      <stop offset="60%" stop-color="#fff" />
      <stop offset="100%" stop-color="#000" />
    </radialGradient>
    <mask id="vignette"><rect width="${W}" height="${H}" fill="url(#fade)" /></mask>
    <filter id="shadow" x="-20%" y="-30%" width="140%" height="170%">
      <feDropShadow dx="0" dy="6" stdDeviation="8" flood-color="${t.shadow}" flood-opacity="${t.shadowOpacity}" />
    </filter>
    <filter id="glow" x="-30%" y="-60%" width="160%" height="220%">
      <feGaussianBlur stdDeviation="3" result="b" />
      <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
    </filter>
  </defs>
  <style>
    .wire { stroke: ${t.border}; stroke-width: 2; stroke-dasharray: 5 7; fill: none; }
    .flow { stroke-width: 3; stroke-dasharray: 3 11; stroke-linecap: round; fill: none; animation: flow 0.9s linear infinite; }
    .pin { fill: ${t.surface}; stroke: ${t.accent}; stroke-width: 2; }
    .card { fill: ${t.surface}; stroke: ${t.border}; stroke-width: 1.5; }
    .letter { font: 700 16px ${FONT}; fill: #ffffff; }
    .name { font: 650 15px ${FONT}; fill: ${t.ink}; }
    .native { font: 500 11.5px ${MONO}; fill: ${t.muted}; }
    .title { font: 700 17px ${MONO}; fill: ${t.ink}; }
    .chip { fill: ${t.chipBg}; }
    .member { font: 600 11.5px ${MONO}; fill: ${t.accent}; }
    .label { font: 500 12px ${FONT}; fill: ${t.muted}; }
    .active { font: 700 13px ${FONT}; }
    .on { opacity: 0; animation: on 10s ease-in-out infinite; }
    ${still >= 0 ? `.on, .flow, .orbit { animation: none; } .on.still { opacity: 1; }` : ''}
    .orbit { fill: none; stroke: ${t.accent}; stroke-opacity: 0.18; stroke-width: 1.5; stroke-dasharray: 2 9; animation: spin 60s linear infinite; transform-origin: ${CX}px ${CY}px; }
    @keyframes on { 0% { opacity: 0 } 3% { opacity: 1 } 17% { opacity: 1 } 20% { opacity: 0 } 100% { opacity: 0 } }
    @keyframes flow { to { stroke-dashoffset: -28 } }
    @keyframes spin { to { transform: rotate(360deg) } }
    @media (prefers-reduced-motion: reduce) {
      .on, .flow, .orbit { animation: none; }
      .on[style*="delay:0s"] { opacity: 1; }
    }
  </style>
  <rect width="${W}" height="${H}" fill="url(#dots)" mask="url(#vignette)" />
  <ellipse cx="${CX}" cy="${CY}" rx="250" ry="170" fill="url(#halo)" />
  <ellipse cx="${CX}" cy="${CY}" rx="${RX}" ry="${RY}" class="orbit" />
  <g fill="none">${connectors}
  </g>
  <g>
    <rect x="${f(hubX)}" y="${f(hubY)}" width="${HUB_W}" height="${HUB_H}" rx="22" fill="${t.surface}" stroke="url(#hubBorder)" stroke-width="2.5" filter="url(#shadow)" />
    <text x="${f(hubX + 18)}" y="${f(hubY + 32)}" class="title">StateStore&lt;S&gt;</text>
    <circle cx="${f(hubX + HUB_W - 24)}" cy="${f(hubY + 27)}" r="5" fill="${t.accentSoft}">
      <animate attributeName="opacity" values="1;0.35;1" dur="2s" repeatCount="indefinite" />
    </circle>
      ${chips}
    <text x="${f(hubX + 18)}" y="${f(hubY + HUB_H - 17)}" class="label">adapter:</text>
      ${activeNames}
  </g>
  <g>${cartridges}
  </g>
</svg>
`;
}

mkdirSync('src/assets', { recursive: true });
mkdirSync('public/images', { recursive: true });
writeFileSync('src/assets/hero-light.svg', svg(themes.light));
writeFileSync('src/assets/hero-dark.svg', svg(themes.dark));
writeFileSync('public/images/hero.svg', svg(themes.light));
writeFileSync('public/images/hero-dark.svg', svg(themes.dark));
mkdirSync('scripts/.cache', { recursive: true });
writeFileSync('scripts/.cache/hero-still-dark.svg', svg(themes.dark, { still: 4 }));
console.log('hero: 4 files written');
