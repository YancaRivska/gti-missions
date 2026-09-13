import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
const source=await readFile('share-achievement.js','utf8');
async function share(height,available,fail=false,activity=null){
 const texts=[];const calls={downloads:0,shares:0};const drawing={createLinearGradient:()=>({addColorStop(){}}),createRadialGradient:()=>({addColorStop(){}}),beginPath(){},moveTo(){},lineTo(){},stroke(){},closePath(){},fill(){},strokeRect(){},drawImage(){},fillRect(){},fillText(text){texts.push(text);},measureText:t=>({width:t.length*16})};
 const canvas={getContext:()=>drawing,toBlob:callback=>callback(new Blob(['image'],{type:'image/png'}))};
 const context=vm.createContext({Blob,File,URL,Error,Image:class {set src(value){this.onerror();}},clearTimeout(){},setTimeout:callback=>callback(),document:{createElement:tag=>tag==='canvas'?canvas:{click(){calls.downloads++;}}},navigator:{canShare:()=>available,share:async()=>{calls.shares++;if(fail)throw new Error('Unavailable');}}});
 const module=new vm.SourceTextModule(source,{context});await module.link(()=>{});await module.evaluate();
 if(activity)await module.namespace.shareActivity(activity,{username:"player"},height);else await module.namespace.shareAchievement({id:'aqua-days-7',icon:'💧',name:'Hidratado 7',description:'Completei sete dias de água'},{username:'player'},'Setembro 2026',height);
 if(activity){assert.ok(texts.includes("MISSÃO DO DIA"));assert.ok(texts.some(t=>t.includes(activity.detail)));assert.ok(texts.some(t=>t.includes("+0 XP")));assert.ok(texts.includes("gti-missions-yanca-rivska.vercel.app"));}
 return {...calls,width:canvas.width,height:canvas.height};
}
test('Story uses 1080x1920 and native file sharing',async()=>assert.deepEqual(await share(1920,true),{downloads:0,shares:1,width:1080,height:1920}));
test('Square downloads 1080x1080 without Web Share support',async()=>assert.deepEqual(await share(1080,false),{downloads:1,shares:0,width:1080,height:1080}));
test('Rejected native sharing falls back to image download',async()=>assert.deepEqual(await share(1080,true,true),{downloads:1,shares:1,width:1080,height:1080}));

test('Daily activity cards retain real details, zero XP and the working website',async()=>{
 for(const [title,detail,icon] of [['AquaXP League','475 ml de água','💧'],['RAT Tech','Treinei 30 minutos','⚡'],['Desafio da Leitura','O Hobbit · 12 páginas','📖'],['Desafio Sem Tela','30 minutos com minha família','🌿']]){
  assert.deepEqual(await share(1920,false,false,{title,detail,icon,xp:0,date:'13/09/2026'}),{downloads:1,shares:0,width:1080,height:1920});
 }
});
