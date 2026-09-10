const CACHE='gti-missions-v6';
const CORE=['/','/style.css?v=1.2.2','/app.js?v=1.2.2','/manifest.webmanifest?v=1.2.2','/icon.svg','/offline.html'];
const CORE_PATHS=new Set(['/style.css','/app.js','/manifest.webmanifest','/icon.svg','/offline.html']);

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
