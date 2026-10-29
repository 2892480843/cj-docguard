const path=require('node:path');
const theme={primary:'006D77',secondary:'006D77',accent:'E29578',light:'83C5BE',bg:'EDF6F9'};
function txt(s,t,x,y,w,h,size=18,opts={}){s.addText(t,{x,y,w,h,fontFace:'Microsoft YaHei',fontSize:size,color:theme.primary,margin:0,breakLine:false,valign:'mid',...opts});}
function rect(s,x,y,w,h,c=theme.light){s.addShape('rect',{x,y,w,h,fill:{color:c},line:{color:c}});}
function box(s,x,y,w,h,title,body,fill=theme.light){rect(s,x,y,w,h,fill);txt(s,title,x+.18,y+.16,w-.36,.43,w<3?18:20,{bold:true});txt(s,body,x+.18,y+.77,w-.36,h-.91,w<3?15:16,{valign:'top',paraSpaceAfterPt:5});}
function base(p,n,title,kicker,source){const s=p.addSlide();s.background={color:theme.bg};txt(s,kicker,.48,.23,9,.24,11,{bold:true});txt(s,title,.48,.77,9,.72,title.length>23?27:30,{bold:true});txt(s,source,.48,5.13,8.45,.23,8.5);s.addShape('ellipse',{x:9.3,y:5.1,w:.4,h:.4,fill:{color:theme.accent},line:{color:theme.accent}});txt(s,String(n),9.3,5.15,.4,.22,11,{align:'center',bold:true});return s;}
const dimensions={'web-api.png':[1280,1122],'web-unicode-original.png':[1280,2215],'web-unicode-fixed.png':[1280,2215],'web-link-failures.png':[1280,1259]};
function shot(s,file,x,y,w,region=[0,0,1,1]){const [iw,ih]=dimensions[file];const [cx,cy,cw,ch]=region;const h=w*(ih*ch)/(iw*cw);s.addImage({path:path.join(__dirname,'../../evidence',file),x,y,w:w/cw,h:h/ch,sizing:{type:'crop',x:cx*w/cw,y:cy*h/ch,w,h},altText:`R2真实网页截图，展示局部：${file}`});return h;}
function metric(s,value,label,x,y,w=2.6){txt(s,value,x,y,w,.6,35,{bold:true});txt(s,label,x,y+.66,w,.45,15,{valign:'top'});}
function notes(s,c){s.addNotes(`【主讲计划】${c.start}—${c.end}，${c.seconds}秒（含操作；不是已计时成绩）。\n【讲述原话】${c.spoken}\n【操作与指向】${c.action}\n【超时切换】${c.fallback}\n【6分钟版精简原话】${c.short_spoken}
【8分钟版可补充】${c.long_extra||'保持收尾，不新增内容'}
【证据】${c.evidence}`);}
module.exports={theme,txt,rect,box,base,shot,metric,notes};
