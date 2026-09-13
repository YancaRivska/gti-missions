/* Isolated browser fixture: blocks ALL Supabase traffic. Never included in dist. */
(()=>{
 const uid='00000000-0000-4000-a000-000000000001';
 const person={user_id:uid,display_name:'Player de teste',username:'player_teste',water_target_ml:1000,water_container_ml:475,water_container_label:'Garrafa',exercise_weekly_target:3,terms_version:'1.2',accepted_terms_at:'2026-09-01T12:00:00Z',profile_visibility:'community',show_progress:true,show_badges:true,show_notes:true,show_history:false};
 localStorage.setItem('gti_missions_session_v1',JSON.stringify({access_token:'local-fixture-not-a-token',expires_at:9999999999}));
 let water=525,trained=false,notes=[];const requests=new Map();
 const season={id:'season-test',name:'MISSÃO — SETEMBRO 2026',start_date:'2026-09-01',end_date:'2026-09-30',joined:true,requires_code:false,status:'active'};
 const badge={id:'aqua-days-1',name:'Primeira Gota',description:'Conclua a missão em 1 dia no total.',icon:'💧',state:'unlocked'};
 const originalFetch=window.fetch;
 window.fetch=async(input,options={})=>{
  const url=new URL(String(input),location.origin);if(url.origin===location.origin)return originalFetch(input,options);
  if(!url.hostname.endsWith('.supabase.co'))throw new Error('Fixture blocks external traffic');
  const args=options.body?JSON.parse(options.body):{},path=url.pathname;let data;
  if(path==='/auth/v1/user')data={id:uid,is_anonymous:false};
  else if(path.includes('/gti_missions_profiles')){if(options.method==='PATCH')Object.assign(person,args);data=[person];}
  else if(path.includes('/gti_missions_notes')){
   const id=url.searchParams.get('id')?.slice(3);
   if(options.method==='POST')notes.unshift({...args,id:crypto.randomUUID(),created_at:new Date().toISOString()});
   if(options.method==='PATCH')Object.assign(notes.find(n=>n.id===id)||{},args);
   if(options.method==='DELETE')notes=notes.filter(n=>n.id!==id);
   data=notes;
  }
  else if(path.endsWith('gti_missions_current_season'))data=season;
  else if(path.endsWith('gti_missions_is_admin'))data=false;
  else if(path.endsWith('gti_missions_custom_challenge_statuses'))data=[];
  else if(path.endsWith('gti_missions_my_stats')||path.endsWith('gti_missions_my_progress'))data={water_today_ml:water,water_target_ml:1000,water_week_days:water>=1000?1:0,water_streak:1,activity_streak:2,exercise_week_days:trained?1:0,exercise_week_target:3,total_xp:75,monthly_xp:75,monthly_rank:1,badges:1,exercise_today_completed:trained,next_badge:'Primeira Gota'};
  else if(path.endsWith('gti_missions_submit_water')){
   if(requests.has(args.p_request_id))data=requests.get(args.p_request_id);else{const before=water;water+=args.p_amount_ml;data={today_ml:water,target_ml:1000,goal_met:water>=1000,xp_awarded:before<1000&&water>=1000?55:5,unlocked_badges:before<1000&&water>=1000?[badge]:[]};requests.set(args.p_request_id,data);}
  }
  else if(path.endsWith('gti_missions_submit_exercise')){data={xp_awarded:trained?0:30,already_completed:trained,unlocked_badges:[]};trained=true;}
  else if(path.endsWith('gti_missions_collection'))data=Array.from({length:30},(_,i)=>i?{id:'locked-'+i,name:i%5===0?'Emblema secreto':`${i+1} metas concluídas`,icon:'💧',description:'Continue sua missão.',state:i%5===0?'secret':'locked'}:badge);
  else if(path.endsWith('gti_missions_ranking_page')||path.endsWith('gti_missions_ranking'))data=[{username:person.username,display_name:person.display_name,xp:75,rank:1,score:1000,participating_challenges:2}];
  else if(path.endsWith('gti_missions_members'))data=[person];
  else if(path.endsWith('gti_missions_member'))data={...person,total_xp:75,level:1,streak:2,challenges:[{name:'AquaXP',days:1}],badges:[badge],notes:notes.filter(n=>n.visibility==='public')};
  else if(path.endsWith('gti_missions_history'))data=[{...season,xp:75,water_days:1,workout_days:1}];
  else data=[];
  return new Response(JSON.stringify(data),{status:200,headers:{'content-type':'application/json'}});
 };
})();
