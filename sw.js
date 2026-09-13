const CACHE='gti-missions-v5.1.0-rpg-ui';
const CORE=['/offline.html','/icon.svg'];
const CORE_PATHS=new Set(['/product.js','/share-achievement.js','/style.css','/water-game.js','/app.js','/universe-ui.js','/manifest.webmanifest','/assets/ui/gti-missions-logo.svg','/assets/water/adventure-map-v1.webp','/assets/mascot/chalote-hero-v1.webp','/assets/mascot/scarlote-cyber-v1.webp','/assets/challenges/aquaxp/chalote-aquaxp-v1.webp','/assets/challenges/rat-tech/chalote-rat-tech-v1.webp','/assets/challenges/reading/chalote-reading-v1.webp','/assets/challenges/screen-free/chalote-screen-free-v1.webp','/icon.svg','/offline.html']);

self.addEventListener('install',event=>{
  event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(CORE)).catch(()=>{}));
  self.skipWaiting();
});

self.addEventListener('activate',event=>{
  event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key!==CACHE).map(key=>caches.delete(key)))));
  self.clients.claim();
});

async function networkFirst(request,fallback){
  const cache=await caches.open(CACHE);
  try{
    const response=await fetch(request);
    if(response.ok)await cache.put(request,response.clone());
    return response;
  }catch{
    return (await cache.match(request))||(fallback&&await cache.match(fallback))||new Response('Offline',{status:503});
  }
}

self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET')return;
  const url=new URL(request.url);
  if(url.origin!==self.location.origin)return;
  if(request.mode==='navigate'){
    event.respondWith(networkFirst(request,'/offline.html'));
    return;
  }
  if(url.pathname.startsWith('/assets/')){event.respondWith(caches.open(CACHE).then(async cache=>{const hit=await cache.match(request);if(hit)return hit;const response=await fetch(request);if(response.ok)await cache.put(request,response.clone());return response;}));return;}
  if(CORE_PATHS.has(url.pathname))event.respondWith(networkFirst(request));
});
