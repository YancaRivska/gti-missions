const CACHE='gti-missions-v12';
const CORE=['/','/style.css?v=4.0.0','/water-game.js?v=4.0.0','/app.js?v=4.0.0','/universe-ui.js?v=4.0.0','/manifest.webmanifest?v=4.0.0','/assets/ui/gti-missions-logo.svg','/assets/water/adventure-map-v1.webp','/assets/mascot/chalote-hero-v1.webp','/assets/challenges/aquaxp/chalote-aquaxp-v1.webp','/assets/challenges/rat-tech/chalote-rat-tech-v1.webp','/assets/challenges/reading/chalote-reading-v1.webp','/assets/challenges/screen-free/chalote-screen-free-v1.webp','/icon.svg','/offline.html'];
const CORE_PATHS=new Set(['/style.css','/water-game.js','/app.js','/universe-ui.js','/manifest.webmanifest','/assets/ui/gti-missions-logo.svg','/assets/water/adventure-map-v1.webp','/assets/mascot/chalote-hero-v1.webp','/assets/challenges/aquaxp/chalote-aquaxp-v1.webp','/assets/challenges/rat-tech/chalote-rat-tech-v1.webp','/assets/challenges/reading/chalote-reading-v1.webp','/assets/challenges/screen-free/chalote-screen-free-v1.webp','/icon.svg','/offline.html']);

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
    return (await cache.match(request,{ignoreSearch:true}))||(fallback&&await cache.match(fallback));
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
  if(CORE_PATHS.has(url.pathname))event.respondWith(networkFirst(request));
});
