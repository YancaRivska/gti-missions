import {cp,mkdir,rm,readFile,access} from 'node:fs/promises';
const files=['index.html','app.js','universe-ui.js','water-game.js','product.js','share-achievement.js','style.css','sw.js','manifest.webmanifest','icon.svg','offline.html','health.json','assets'];
await Promise.all(files.map(f=>access(f)));
for(const file of ['vercel.json','manifest.webmanifest','health.json'])JSON.parse(await readFile(file,'utf8'));
await rm('dist',{recursive:true,force:true});await mkdir('dist');
for(const file of files)await cp(file,`dist/${file}`,{recursive:true});
console.log('Static production build: dist/ (runtime dependencies: 0)');
