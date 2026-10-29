// Shared layout; no browser runtime or project dependencies are needed to render slides.
const theme={primary:'006D77',secondary:'006D77',accent:'E29578',light:'83C5BE',bg:'EDF6F9'};
function txt(s,t,x,y,w,h,size=18,opts={}){s.addText(t,{x,y,w,h,fontFace:'Microsoft YaHei',fontSize:size,color:theme.primary,margin:0,breakLine:false,...opts});}
function rect(s,x,y,w,h,c=theme.light){s.addShape('rect',{x,y,w,h,fill:{color:c},line:{color:c}});}
function box(s,x,y,w,h,title,body,fill=theme.light){rect(s,x,y,w,h,fill);const short=h<1.6;txt(s,title,x+.22,y+.18,w-.44,.44,w<3||short?18:21,{bold:true});txt(s,body,x+.22,y+(short?.68:.86),w-.44,h-(short?.79:1.0),short?13:(w<3?14:16),{paraSpaceAfterPt:5,valign:'top'});}
function base(p,n,title,kicker,source){let s=p.addSlide();s.background={color:theme.bg};txt(s,kicker,.48,.24,8.8,.25,11,{bold:true,charSpacing:1.3});txt(s,title,.48,.78,9.0,.72,32,{bold:true});txt(s,source,.48,5.13,8.3,.23,9);s.addShape('ellipse',{x:9.3,y:5.1,w:.4,h:.4,fill:{color:theme.accent},line:{color:theme.accent}});txt(s,String(n),9.3,5.16,.4,.19,11,{align:'center',bold:true});return s;}
module.exports={theme,txt,rect,box,base};
