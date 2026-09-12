import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const javascriptFiles = ['config.js', 'core/domain.js', 'app.js', 'universe-ui.js', 'water-game.js', 'sw.js'];
for (const file of javascriptFiles) execFileSync(process.execPath, ['--check', file], { stdio: 'inherit' });

const trackedFiles = execFileSync('git', ['ls-files'], { encoding: 'utf8' }).trim().split('\n').filter(Boolean);
const violations = [];
for (const file of trackedFiles) {
  if (!/\.(?:js|mjs|ts|html|json|md|sql)$/.test(file)) continue;
  const source = readFileSync(file, 'utf8');
  if (/\b(?:TODO|FIXME|HACK)\b/.test(source)) violations.push(`${file}: marcador temporário`);
  if (/\bas any\b|\bas unknown as\b/.test(source)) violations.push(`${file}: cast inseguro`);
  if (/sb_secret_|SUPABASE_SERVICE_ROLE_KEY\s*[=:]\s*['"][^'"]+/.test(source)) violations.push(`${file}: possível segredo`);
}
if (violations.length) {
  console.error(violations.join('\n'));
  process.exitCode = 1;
}
