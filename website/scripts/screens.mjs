// Frames the simulator screenshots in screenshots/ as phones and builds the
// composite images: a fanned trio for the home page and the 1200x630 social
// preview. Run with `npm run images` after `scripts/hero.mjs`.
//
// Outputs (WebP for the site, PNG for the social card):
//   src/assets/screens/<name>.webp
//   src/assets/screens/trio.webp
//   public/og.png
import { mkdirSync, readFileSync, readdirSync } from 'node:fs';
import sharp from 'sharp';

const SRC = 'screenshots';
const OUT = 'src/assets/screens';
mkdirSync(OUT, { recursive: true });

// iPhone 17 simulator screenshots are 1206 x 2622.
const SW = 1206;
const SH = 2622;
const BEZEL = 44;
const SCREEN_R = 168;
const FW = SW + BEZEL * 2;
const FH = SH + BEZEL * 2;
const PAD = 120; // room for the shadow

const dataUri = (file) => `data:image/png;base64,${readFileSync(file).toString('base64')}`;

/** One phone as an SVG group, drawn at the origin, FW x FH. */
function phone(href, id) {
	return `
  <g>
    <rect x="-7" y="${FH * 0.2}" width="10" height="150" rx="5" fill="#2b3135" />
    <rect x="-7" y="${FH * 0.27}" width="10" height="230" rx="5" fill="#2b3135" />
    <rect x="-7" y="${FH * 0.36}" width="10" height="230" rx="5" fill="#2b3135" />
    <rect x="${FW - 3}" y="${FH * 0.3}" width="10" height="330" rx="5" fill="#2b3135" />
    <rect width="${FW}" height="${FH}" rx="${SCREEN_R + BEZEL}" fill="url(#body)" />
    <rect x="3" y="3" width="${FW - 6}" height="${FH - 6}" rx="${SCREEN_R + BEZEL - 3}" fill="none" stroke="#5b656b" stroke-opacity="0.65" stroke-width="4" />
    <rect x="${BEZEL - 8}" y="${BEZEL - 8}" width="${SW + 16}" height="${SH + 16}" rx="${SCREEN_R + 8}" fill="#050607" />
    <clipPath id="clip-${id}"><rect x="${BEZEL}" y="${BEZEL}" width="${SW}" height="${SH}" rx="${SCREEN_R}" /></clipPath>
    <image href="${href}" x="${BEZEL}" y="${BEZEL}" width="${SW}" height="${SH}" clip-path="url(#clip-${id})" preserveAspectRatio="none" />
    <rect x="${BEZEL + SW / 2 - 189}" y="${BEZEL + 33}" width="378" height="111" rx="55.5" fill="#050607" />
    <rect x="${BEZEL}" y="${BEZEL}" width="${SW}" height="${SH}" rx="${SCREEN_R}" fill="url(#glare)" />
  </g>`;
}

const defs = `
  <defs>
    <linearGradient id="body" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#3a4247" />
      <stop offset="45%" stop-color="#1c2124" />
      <stop offset="100%" stop-color="#2c3337" />
    </linearGradient>
    <linearGradient id="glare" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.10" />
      <stop offset="35%" stop-color="#ffffff" stop-opacity="0" />
    </linearGradient>
    <filter id="shadow" x="-30%" y="-20%" width="160%" height="140%">
      <feDropShadow dx="0" dy="40" stdDeviation="45" flood-color="#08201c" flood-opacity="0.35" />
    </filter>
  </defs>`;

async function render(svg, file, { width, format = 'webp' }) {
	let img = sharp(Buffer.from(svg), { density: 72 }).resize({ width });
	img = format === 'png' ? img.png({ compressionLevel: 9 }) : img.webp({ quality: 88, alphaQuality: 90 });
	await img.toFile(file);
}

const shots = readdirSync(SRC)
	.filter((f) => f.endsWith('.png'))
	.map((f) => f.replace(/\.png$/, ''));

// One framed phone per screenshot.
for (const name of shots) {
	const W = FW + PAD * 2;
	const H = FH + PAD * 2;
	const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${defs}
  <g transform="translate(${PAD} ${PAD})" filter="url(#shadow)">${phone(dataUri(`${SRC}/${name}.png`), name)}</g>
</svg>`;
	await render(svg, `${OUT}/${name}.webp`, { width: 560 });
}

// Three phones fanned out: the choice, Transactions and Starred.
{
	const W = 4200;
	const H = 3500;
	const place = (name, x, y, deg, scale) =>
		`<g transform="translate(${x} ${y}) rotate(${deg}) scale(${scale}) translate(${-FW / 2} ${-FH / 2})" filter="url(#shadow)">${phone(dataUri(`${SRC}/${name}.png`), name)}</g>`;
	const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${defs}
  ${place('choose', 1080, 1830, -8, 0.88)}
  ${place('starred', 3120, 1830, 8, 0.88)}
  ${place('transactions_cubit', 2100, 1700, 0, 1)}
</svg>`;
	await render(svg, `${OUT}/trio.webp`, { width: 1400 });
}

// The social preview card.
{
	const W = 1200;
	const H = 630;
	const chips = [
		['Cubit', '#6366f1'],
		['GetX', '#e0812f'],
		['MobX', '#e2486f'],
		['Provider', '#0ea5c6'],
		['Riverpod', '#8b5cf6'],
	];
	let cx = 72;
	const chipSvg = chips
		.map(([label, color]) => {
			const w = 22 + label.length * 11.5 + 22;
			const g = `<g transform="translate(${cx} 452)"><rect width="${w}" height="40" rx="20" fill="${color}" fill-opacity="0.16" stroke="${color}" stroke-opacity="0.7" /><circle cx="20" cy="20" r="6" fill="${color}" /><text x="34" y="26.5" class="chip">${label}</text></g>`;
			cx += w + 10;
			return g;
		})
		.join('');
	const s = 0.205;
	const phoneAt = (name, x, y, deg) =>
		`<g transform="translate(${x} ${y}) rotate(${deg}) scale(${s}) translate(${-FW / 2} ${-FH / 2})" filter="url(#shadow)">${phone(dataUri(`${SRC}/${name}.png`), `og-${name}`)}</g>`;
	const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${defs}
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#06201c" />
      <stop offset="100%" stop-color="#0d3a33" />
    </linearGradient>
    <radialGradient id="halo" cx="78%" cy="45%" r="45%">
      <stop offset="0%" stop-color="#3cc7b0" stop-opacity="0.35" />
      <stop offset="100%" stop-color="#3cc7b0" stop-opacity="0" />
    </radialGradient>
    <pattern id="dots" width="24" height="24" patternUnits="userSpaceOnUse"><circle cx="2" cy="2" r="1.3" fill="#3cc7b0" opacity="0.13" /></pattern>
  </defs>
  <style>
    .kicker { font: 600 22px 'Helvetica Neue', Helvetica, Arial, sans-serif; fill: #3cc7b0; letter-spacing: 3px; }
    .title { font: 700 66px Menlo, 'SF Mono', Consolas, monospace; fill: #f2fbf9; }
    .tag { font: 400 31px 'Helvetica Neue', Helvetica, Arial, sans-serif; fill: #cfe7e2; }
    .chip { font: 600 19px 'Helvetica Neue', Helvetica, Arial, sans-serif; fill: #f2fbf9; }
    .foot { font: 500 20px Menlo, 'SF Mono', Consolas, monospace; fill: #8fb9b1; }
  </style>
  <rect width="${W}" height="${H}" fill="url(#bg)" />
  <rect width="${W}" height="${H}" fill="url(#dots)" />
  <rect width="${W}" height="${H}" fill="url(#halo)" />
  <text x="72" y="150" class="kicker">FLUTTER STATE MANAGEMENT</text>
  <text x="68" y="232" class="title">switchable_state</text>
  <text x="72" y="305" class="tag">One state contract for your screens.</text>
  <text x="72" y="350" class="tag">Five interchangeable libraries.</text>
  ${chipSvg}
  <text x="72" y="560" class="foot">flutter pub add switchable_state</text>
  ${phoneAt('choose', 870, 345, -7)}
  ${phoneAt('transactions_riverpod', 1040, 330, 6)}
</svg>`;
	mkdirSync('public', { recursive: true });
	await render(svg, 'public/og.png', { width: W, format: 'png' });
}

console.log(`screens: ${shots.length} phones, trio and og.png written`);
