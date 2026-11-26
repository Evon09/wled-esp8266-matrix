/* ---------- desenhos animados do tempo, 16x16 (sem DOM: este trecho também roda no Node para conferir a arte) ---------- */
const WX_KINDS=[['sol','Sol'],['lua','Noite limpa'],['solnuvem','Sol e nuvens'],['luanuvem','Noite e nuvens'],['nublado','Nublado'],['neblina','Neblina'],['garoa','Garoa'],['chuva','Chuva'],['tempestade','Tempestade'],['neve','Neve']];
const WX_FRAMES=12,WX_DELAY={sol:20,lua:25,solnuvem:25,luanuvem:25,nublado:30,neblina:22,garoa:16,chuva:10,tempestade:12,neve:20}; // atraso em centésimos de segundo
const wxName=k=>(WX_KINDS.find(x=>x[0]===k)||[k,k])[1];
// código de tempo da WMO (o que o Open-Meteo devolve) + dia ou noite -> desenho
function wxKind(code,isDay){
  if(code==null)return null;
  if(code<=1)return isDay?'sol':'lua';
  if(code===2)return isDay?'solnuvem':'luanuvem';
  if(code===45||code===48)return'neblina';
  if(code>=51&&code<=57)return'garoa';
  if((code>=61&&code<=67)||(code>=80&&code<=82))return'chuva';
  if((code>=71&&code<=77)||code===85||code===86)return'neve';
  if(code>=95)return'tempestade';
  return'nublado';
}
const WX_DIG={'0':'75557','1':'26227','2':'71747','3':'71717','4':'55711','5':'74717','6':'74757','7':'71111','8':'75757','9':'75717','-':'00700','°':'75700'};
const WX_CLOUD=['....###....','..######...','.########..','.##########','###########','.#########.'];
// H é a altura da área do desenho: 16 (tela toda) ou 10 (com a temperatura embaixo)
function wxDraw(kind,f,H,px){
  const set=(x,y,c)=>{x=Math.round(x);y=Math.round(y);if(x>=0&&x<16&&y>=0&&y<H)px[y*16+x]=c};
  const t=f/WX_FRAMES,big=H===16,drift=Math.round(Math.sin(t*2*Math.PI));
  const cloud=(ox,oy,main,shade)=>WX_CLOUD.forEach((row,j)=>{for(let i=0;i<row.length;i++)if(row[i]==='#')set(ox+i,oy+j,j>=4?shade:main)});
  const disk=(cx,cy,r,c,core)=>{for(let y=0;y<H;y++)for(let x=0;x<16;x++){const d=Math.hypot(x-cx,y-cy);if(d<=r)set(x,y,core&&d<=r-1.3?core:c)}};
  const crescent=(cx,cy,r)=>{for(let y=0;y<H;y++)for(let x=0;x<16;x++)if(Math.hypot(x-cx,y-cy)<=r&&Math.hypot(x-cx-r*.62,y-cy+r*.38)>r*.9)set(x,y,0xf0e4a0)};
  const stars=list=>list.forEach(([x,y],i)=>{const p=(f+i*5)%WX_FRAMES;if(p<4)set(x,y,0xffffff);else if(p<8)set(x,y,0x506080)});
  // gotas e flocos: cada um percorre a faixa "top..H-1" um número inteiro de vezes por volta, então a animação emenda sem salto
  const fall=(cols,top,turns,fn)=>{const span=H-top;cols.forEach((x,i)=>{const y=top+Math.floor(((t*turns+i*.37)%1)*span);fn(x,y,i)})};
  const R=0xff9000;
  if(kind==='sol'){const long=Math.floor(f/3)%2===0;
    if(big){disk(7.5,7.5,3.7,0xffb000,0xffe030);
      for(const x of [7,8]){for(const y of long?[0,1,2]:[1,2]){set(x,y,R);set(x,15-y,R);set(y,x,R);set(15-y,x,R)}}
      for(const d of long?[2,3]:[1,2,3]){set(d,d,R);set(15-d,d,R);set(d,15-d,R);set(15-d,15-d,R)}}
    else{disk(7.5,4.5,2.7,0xffb000,0xffe030);
      for(const x of long?[2,3]:[1,2,3]){set(x,4,R);set(x,5,R);set(15-x,4,R);set(15-x,5,R)}
      for(const x of [7,8]){set(x,0,R);set(x,9,R)}
      for(const d of long?[1]:[0,1]){set(3+d,d,R);set(12-d,d,R);set(3+d,9-d,R);set(12-d,9-d,R)}}}
  else if(kind==='lua'){if(big){crescent(7,8,5.2);stars([[13,2],[2,3],[14,10],[11,14],[1,13]])}else{crescent(7,4.5,4.2);stars([[13,1],[1,2],[14,7],[1,8]])}}
  else if(kind==='solnuvem'||kind==='luanuvem'){const sx=11,sy=big?4:2.5;
    if(kind==='solnuvem'){disk(sx,sy,big?2.6:2.2,0xffb000,0xffe030);const on=Math.floor(f/3)%2===0,r=big?4:3;
      for(const[dx,dy]of on?[[0,-1],[1,0],[.75,-.75]]:[[-.75,-.75],[.75,.75],[1,0]])set(sx+dx*r,sy+dy*r,R)}
    else{crescent(sx,sy,big?3.2:2.4);stars(big?[[2,2],[14,12],[5,14]]:[[1,1],[6,0]])}
    cloud(1+drift,big?7:3,0xd0dae8,0x7888a0)}
  else if(kind==='nublado'){cloud(5-drift,big?2:0,0x707c90,0x485468);cloud(drift,big?8:4,0xd0dae8,0x7888a0)}
  else if(kind==='neblina'){const pat='#####..###..';(big?[2,4,6,8,10,12,14]:[1,3,5,7,9]).forEach((y,j)=>{for(let x=0;x<16;x++){const s=j%2?-f:f;if(pat[((x+s+j*5)%12+12)%12]==='#')set(x,y,j%2?0x8896a8:0x566272)}})}
  else{const oy=big?1:0,top=oy+6,flash=kind==='tempestade'&&(f===2||f===8);
    if(kind==='tempestade')cloud(2,oy,flash?0xb8c0d8:0x606a80,flash?0x808aa8:0x3a4258);
    else if(kind==='neve')cloud(2+drift,oy,0xc0ccdc,0x6c7c94);
    else cloud(2+drift,oy,0xa8b4c8,0x566478);
    if(kind==='chuva')fall([3,5,7,9,11,13],top,big?2:3,(x,y)=>{set(x,y,0x30a0ff);if(y-1>=top)set(x,y-1,0x0c3c80)});
    else if(kind==='garoa')fall([3,6,9,12],top,big?1:2,(x,y)=>set(x,y,0x60c0ff));
    else if(kind==='neve')fall([2,5,7,10,13],top,1,(x,y,i)=>set(x+Math.round(Math.sin(t*2*Math.PI+i*2)),y,0xffffff));
    else{fall([3,6,12],top,big?2:3,(x,y)=>set(x,y,0x2080e0));
      if(f===2||f===3||f===8){const bolt=big?[[9,7],[8,8],[7,9],[8,9],[9,9],[8,10],[7,11],[6,12]]:[[9,6],[8,7],[9,7],[8,8],[7,9]];bolt.forEach(([x,y])=>set(x,y,0xffe020))}}}
}
const wxTempColor=v=>v<=5?0x40a0ff:v<=15?0x50e0ff:v<=24?0xffffff:v<=31?0xffa000:0xff4020;
function wxTemp(v,px){const s=String(Math.round(v))+'°',w=s.length*4-1;let x=Math.max(0,Math.floor((16-w+1)/2));
  for(const ch of s){const g=WX_DIG[ch];for(let r=0;r<5;r++){const b=+g[r];for(let k=0;k<3;k++)if(b&(4>>k)&&x+k<16)px[(11+r)*16+x+k]=wxTempColor(v)}x+=4}}
// temp = null desenha a tela toda; com número, o desenho fica em cima e a temperatura embaixo
function wxFrames(kind,temp){const withT=temp!=null,out=[];for(let f=0;f<WX_FRAMES;f++){const px=new Uint32Array(256);wxDraw(kind,f,withT?10:16,px);if(withT)wxTemp(temp,px);out.push(px)}return out}
function wxGif(kind,temp,Writer){
  const fr=wxFrames(kind,temp),idx=new Map();for(const f of fr)for(const c of f)if(!idx.has(c))idx.set(c,idx.size);
  let n=2;while(n<idx.size)n<<=1;const pal=[...idx.keys()];while(pal.length<n)pal.push(0);
  const buf=[],w=new Writer(buf,16,16,{palette:pal,loop:0});
  for(const f of fr)w.addFrame(0,0,16,16,Uint8Array.from(f,c=>idx.get(c)),{delay:WX_DELAY[kind]||20,disposal:2});
  return new Uint8Array(buf.slice(0,w.end()))}
