/** Load local official artwork only when a share image is requested.
 * @param {string} path @returns {Promise<HTMLImageElement|null>} */
function artwork(path){return new Promise(resolve=>{const img=new Image();const timer=setTimeout(()=>resolve(null),5000);img.onload=()=>{clearTimeout(timer);resolve(img);};img.onerror=()=>{clearTimeout(timer);resolve(null);};img.src=path;});}
/** @param {{id:string, icon:string, name:string, description:string}} badge @param {{username:string}} player @param {string} season @param {number} height */
export async function shareAchievement(badge,player,season,height){
 const canvas=document.createElement('canvas');canvas.width=1080;canvas.height=[1080,1350,1920].includes(height)?height:1920;height=canvas.height;const ctx=canvas.getContext('2d');if(!ctx)throw new Error('Canvas unavailable');
 const [pink,dark,logo]=await Promise.all([artwork('/assets/mascot/chalote-hero-v1.webp'),artwork('/assets/mascot/scarlote-cyber-v1.webp'),artwork('/assets/ui/gti-missions-logo.svg')]);
 const gradient=ctx.createLinearGradient(0,0,1080,height);gradient.addColorStop(0,'#020d20');gradient.addColorStop(.55,'#111c49');gradient.addColorStop(1,'#030b1b');ctx.fillStyle=gradient;ctx.fillRect(0,0,1080,height);
 // Small vector accents keep exports crisp, without a large background bitmap.
 ctx.strokeStyle='#25466e';ctx.lineWidth=1;for(let x=0;x<1080;x+=90){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,height);ctx.stroke();}for(let y=0;y<height;y+=90){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(1080,y);ctx.stroke();}
 const glow=ctx.createRadialGradient(540,height*.42,20,540,height*.42,620);glow.addColorStop(0,'#3668db88');glow.addColorStop(1,'#030b1b00');ctx.fillStyle=glow;ctx.fillRect(0,0,1080,height);
 ctx.strokeStyle='#4b8cc8';ctx.lineWidth=3;ctx.strokeRect(32,32,1016,height-64);ctx.textAlign='center';
 /** @param {string} text @param {number} y @param {number} size @param {string} [color] */
 function line(text,y,size,color='#fff'){if(!ctx)return;ctx.fillStyle=color;ctx.font=`800 ${size}px system-ui, sans-serif`;while(ctx.measureText(text).width>900&&size>24){size-=2;ctx.font=`800 ${size}px system-ui, sans-serif`;}ctx.fillText(text,540,y);}
 if(logo)ctx.drawImage(logo,370,height*.045,340,130);else line('GTI MISSIONS',height*.12,62,'#8ceaff');
 line('CONQUISTA',height*.195,64,'#9eeaff');line('DESBLOQUEADA',height*.195+73,64,'#e7dbff');
 const artTop=height*.29,artHeight=height*.33;
 if(pink)ctx.drawImage(pink,80,artTop,artHeight*.75,artHeight);
 if(dark)ctx.drawImage(dark,1000-artHeight*.8,artTop,artHeight*.8,artHeight);
 const cy=height*.51,r=height===1080?135:180;
 const badgeGradient=ctx.createLinearGradient(360,cy-r,720,cy+r);badgeGradient.addColorStop(0,'#81e8ff');badgeGradient.addColorStop(.3,'#2864bb');badgeGradient.addColorStop(.7,'#0d2347');badgeGradient.addColorStop(1,'#b36df5');
 ctx.beginPath();for(let i=0;i<6;i++){const angle=(i*60-90)*Math.PI/180;const x=540+Math.cos(angle)*r,y=cy+Math.sin(angle)*r;if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);}ctx.closePath();ctx.fillStyle=badgeGradient;ctx.fill();ctx.strokeStyle='#a7e7ff';ctx.lineWidth=6;ctx.stroke();line(badge.icon,cy+38,100);
 line(badge.name,height*.69,60);ctx.font='32px system-ui, sans-serif';ctx.fillStyle='#c8daef';
 const words=badge.description.split(' ');let text='',y=height*.745;for(const word of words){if(ctx.measureText(text+' '+word).width>870){ctx.fillText(text,540,y);y+=42;text=word;}else text+=(text?' ':'')+word;}ctx.fillText(text,540,y);
 line('@'+player.username,height*.85,38,'#8ceaff');line(season,height*.905,28,'#b7c8e6');line('GALERA DO TI · PROGRESSO REAL',height*.96,24,'#8ea9c9');
 /** @type {Blob|null} */
 const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/png'));if(!blob)throw new Error('Image failed');const file=new File([blob],`gti-missions-${badge.id}-${height}.png`,{type:'image/png'});
 if(navigator.canShare?.({files:[file]})){try{await navigator.share({files:[file],title:badge.name});return;}catch(e){if(e instanceof Error && e.name==='AbortError')throw e;}}
 const url=URL.createObjectURL(blob),link=document.createElement('a');link.href=url;link.download=file.name;link.click();setTimeout(()=>URL.revokeObjectURL(url),10000);
}
