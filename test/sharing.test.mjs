import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
const source=await readFile('share-achievement.js','utf8');
async function share(height,available,fail=false){
 const calls={downloads:0,shares:0};const drawing={createLinearGradient:()=>({addColorStop(){}}),createRadialGradient:()=>({addColorStop(){}}),beginPath(){},moveTo(){},lineTo(){},stroke(){},closePath(){},fill(){},strokeRect(){},drawImage(){},fillRect(){},fillText(){},measureText:t=>({width:t.length*16})};
 const canvas={getContext:()=>drawing,toBlob:callback=>callback(new Blob(['image'],{type:'image/png'}))};
 const context=vm.createContext({Blob,File,URL,Error,Image:class {set src(value){this.onerror();}},clearTimeout(){},setTimeout:callback=>callback(),document:{createElement:tag=>tag==='canvas'?canvas:{click(){calls.downloads++;}}},navigator:{canShare:()=>available,share:async()=>{calls.shares++;if(fail)throw new Error('Unavailable');}}});
 const module=new vm.SourceTextModule(source,{context});await module.link(()=>{});await module.evaluate();
 await module.namespace.shareAchievement({id:'aqua-days-7',icon:'💧',name:'Hidratado 7',description:'Completei sete dias de água'},{username:'player'},'Setembro 2026',height);
 return {...calls,width:canvas.width,height:canvas.height};
}
test('Story uses 1080x1920 and native file sharing',async()=>assert.deepEqual(await share(1920,true),{downloads:0,shares:1,width:1080,height:1920}));
test('Square downloads 1080x1080 without Web Share support',async()=>assert.deepEqual(await share(1080,false),{downloads:1,shares:0,width:1080,height:1080}));
test('Rejected native sharing falls back to image download',async()=>assert.deepEqual(await share(1080,true,true),{downloads:1,shares:1,width:1080,height:1080}));
