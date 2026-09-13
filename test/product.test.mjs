import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
import {Window} from 'happy-dom';
async function fixture(view='app'){
 const window=new Window({url:`http://localhost/?view=${view}`});window.document.body.innerHTML='<div id="app"></div>';
 window.matchMedia=()=>({matches:true,addEventListener(){},removeEventListener(){}});window.confirm=()=>true;
 window.HTMLDialogElement.prototype.showModal=function(){this.open=true;};
 window.HTMLDialogElement.prototype.close=function(){this.open=false;this.dispatchEvent(new window.Event('close'));};
 const context=vm.createContext(window);const modules=new Map();
 async function importModule(specifier){const path=specifier.split('?')[0].replace(/^\//,'');if(modules.has(path))return modules.get(path);const module=new vm.SourceTextModule(await readFile(path,'utf8'),{context,identifier:path,importModuleDynamically:importModule});modules.set(path,module);await module.link(importModule);await module.evaluate();return module;}
 for(const path of ['test/preview-fixtures.js','water-game.js','app.js','universe-ui.js'])new vm.Script(await readFile(path,'utf8'),{filename:path,importModuleDynamically:importModule}).runInContext(context);
 async function settle(){for(let i=0;i<20;i++)await new Promise(r=>setTimeout(r,5));}
 await settle();return {window,context,settle,run:code=>new vm.Script(code,{importModuleDynamically:importModule}).runInContext(context),close:()=>window.happyDOM.abort()};
}
test('Home prioritizes today, season, XP and next badge without duplicate decorative panels',async()=>{const f=await fixture();const d=f.window.document,text=d.body.textContent;assert.match(text,/SETEMBRO/);assert.match(text,/MISSÕES DE HOJE/);assert.match(text,/525/);assert.match(text,/PRÓXIMO EMBLEMA/);assert.equal(d.querySelector('.overall-card'),null);assert.equal(d.querySelector('.compact-player-card'),null);await f.close();});
test('Public landing renders one restrained hero instead of the oversized legacy landing',async()=>{const f=await fixture('home');const d=f.window.document;assert.equal(d.querySelectorAll('.welcome-panel').length,1);assert.equal(d.querySelector('.mission-hero'),null);assert.match(d.body.textContent,/Um passo por dia/);await f.close();});
test('Water uses configured 475ml container, unlocks once and has no evidence picker',async()=>{const f=await fixture('aqua');const d=f.window.document;assert.equal(d.querySelector('#openCamera'),null);d.querySelector('[data-water="475"]').click();await f.settle();assert.match(d.body.textContent,/NOVO EMBLEMA/);d.querySelector('dialog').close();await f.settle();assert.match(d.querySelector('.meter-copy').textContent,/1.000/);await f.close();});
test('Workout cancellation writes nothing; confirmation completes and duplicate is harmless',async()=>{const f=await fixture('tech');const d=f.window.document;f.window.confirm=()=>false;d.querySelector('#ratForm').dispatchEvent(new f.window.Event('submit',{cancelable:true}));await f.settle();assert.equal((await f.run('stats()')).exercise_week_days,0);f.window.confirm=()=>true;d.querySelector('#ratForm').dispatchEvent(new f.window.Event('submit',{cancelable:true}));await f.settle();assert.equal((await f.run('stats()')).exercise_week_days,1);assert.equal(d.querySelector('#openCamera'),null);await f.close();});
test('Notes default private, support save/edit/delete and escape markup',async()=>{const f=await fixture('notes');const d=f.window.document;let form=d.querySelector('#noteForm');assert.equal(form.elements.visibility.value,'private');form.elements.content.value='<img src=x onerror=alert(1)> Minha leitura';form.dispatchEvent(new f.window.Event('submit',{cancelable:true}));await f.settle();assert.equal(d.querySelector('#notesList img'),null);assert.match(d.querySelector('#notesList').textContent,/Minha leitura/);d.querySelector('[data-edit]').click();form.elements.content.value='Nota editada';form.dispatchEvent(new f.window.Event('submit',{cancelable:true}));await f.settle();assert.match(d.querySelector('#notesList').textContent,/Nota editada/);d.querySelector('[data-delete]').click();await f.settle();assert.match(d.querySelector('#notesList').textContent,/primeira nota/);await f.close();});
test('Collection and ranking route to member profile',async()=>{const f=await fixture('collection');const d=f.window.document;assert.equal(d.querySelectorAll('.achievement-tile').length,30);assert.match(d.body.textContent,/Emblema secreto/);await f.run("nav('league')");await f.settle();assert.equal(d.querySelectorAll('[data-ranking-type]').length,5);d.querySelector('[data-member]').click();await f.settle();assert.match(d.body.textContent,/Mundos ativos/);await f.close();});
test('Avatar update clears the cached profile and survives a later screen failure',async()=>{
 const f=await fixture('profile');
 await f.run("uploadAvatar=async()=> 'test/new.webp';deleteAvatar=async path=>{window.deletedAvatar=path};");
 await f.window.document.querySelector('#photoFile').onchange({target:{files:[{}],value:'file'}});
 assert.equal((await f.run('profile()')).avatar_path,'test/new.webp');
 await f.run("uploadAvatar=async()=> 'test/newer.webp';renderProfile=async()=>{throw new Error('Screen failed')};window.deletedAvatar=null;");
 await f.window.document.querySelector('#photoFile').onchange({target:{files:[{}],value:'file'}});
 assert.notEqual(f.window.deletedAvatar,'test/newer.webp');
 assert.equal((await f.run('profile()')).avatar_path,'test/newer.webp');await f.close();
});
test('A successful daily water entry exposes sharing with actual amount and earned XP',async()=>{
 const f=await fixture('aqua');const d=f.window.document;
 d.querySelector('[data-water="475"]').click();await f.settle();d.querySelector('dialog').close();await f.settle();
 assert.match(d.querySelector('.activity-receipt').textContent,/475 ml/);
 assert.match(d.querySelector('.activity-receipt').textContent,/55 XP/);
 d.querySelector('[data-share-activity]').click();assert.equal(d.querySelectorAll('dialog [data-size]').length,2);await f.close();
});
