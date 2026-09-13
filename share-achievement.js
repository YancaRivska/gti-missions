/** @param {{id:string, icon:string, name:string, description:string}} badge @param {{username:string}} player @param {string} season @param {number} height */
export async function shareAchievement(badge,player,season,height){
 const canvas=document.createElement('canvas');canvas.width=1080;canvas.height=height;const context=canvas.getContext('2d');if(!context)throw new Error('Canvas unavailable');const ctx=context;
 const gradient=ctx.createLinearGradient(0,0,1080,height);gradient.addColorStop(0,'#041b2e');gradient.addColorStop(1,'#301c60');ctx.fillStyle=gradient;ctx.fillRect(0,0,1080,height);ctx.textAlign='center';
 /** @param {string} text @param {number} y @param {number} size @param {string} [color] */
 function line(text,y,size,color='#fff'){ctx.fillStyle=color;ctx.font=`700 ${size}px system-ui, sans-serif`;while(ctx.measureText(text).width>920&&size>24){size-=2;ctx.font=`700 ${size}px system-ui, sans-serif`;}ctx.fillText(text,540,y);}
 line('GTI MISSIONS',height*.15,62,'#8ceaff');line(badge.icon,height*.35,140);line(badge.name,height*.48,64);ctx.font='36px system-ui, sans-serif';ctx.fillStyle='#dce9ff';
 const words=badge.description.split(' ');let text='',y=height*.58;for(const word of words){if(ctx.measureText(text+' '+word).width>870){ctx.fillText(text,540,y);y+=48;text=word;}else text+=(text?' ':'')+word;}ctx.fillText(text,540,y);
 line('@'+player.username,height*.78,40);line(season,height*.86,30,'#aee4ff');line('GALERA DO TI',height*.94,30);
 /** @type {Blob|null} */
 const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/png'));if(!blob)throw new Error('Image failed');const file=new File([blob],`gti-missions-${badge.id}-${height}.png`,{type:'image/png'});
 if(navigator.canShare?.({files:[file]})){try{await navigator.share({files:[file],title:badge.name});return;}catch(e){if(e instanceof Error && e.name==='AbortError')throw e;}}
 const url=URL.createObjectURL(blob),link=document.createElement('a');link.href=url;link.download=file.name;link.click();setTimeout(()=>URL.revokeObjectURL(url),10000);
}
