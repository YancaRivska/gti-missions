import { access, cp, mkdir, readFile, rm } from 'node:fs/promises';

const requiredFiles = [
  'index.html', 'config.js', 'core/domain.js', 'app.js', 'universe-ui.js', 'water-game.js',
  'style.css', 'sw.js', 'manifest.webmanifest', 'offline.html', 'health.json',
];
await Promise.all(requiredFiles.map(file => access(file)));
JSON.parse(await readFile('manifest.webmanifest', 'utf8'));
JSON.parse(await readFile('health.json', 'utf8'));
JSON.parse(await readFile('vercel.json', 'utf8'));

const html = await readFile('index.html', 'utf8');
for (const script of ['config.js', 'core/domain.js', 'water-game.js', 'app.js', 'universe-ui.js']) {
  if (!html.includes(`/${script}`)) throw new Error(`index.html não referencia ${script}`);
}

const outputDirectory = 'dist';
const publicFiles = [
  'index.html', 'config.js', 'app.js', 'universe-ui.js', 'water-game.js', 'style.css',
  'sw.js', 'manifest.webmanifest', 'offline.html', 'health.json', 'icon.svg',
];

await rm(outputDirectory, { recursive: true, force: true });
await mkdir(`${outputDirectory}/core`, { recursive: true });
await Promise.all(publicFiles.map(file => cp(file, `${outputDirectory}/${file}`)));
await cp('core/domain.js', `${outputDirectory}/core/domain.js`);
await cp('assets', `${outputDirectory}/assets`, { recursive: true });
