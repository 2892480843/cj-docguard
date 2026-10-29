const {txt,rect,box,base,shot,metric,notes}=require('./theme');
const content=require('../content.json').slides;
const slideConfig={type:'cover',index:1};
function createSlide(p,t){
const s=p.addSlide();s.background={color:t.primary};txt(s,'CJ-DocGuard',.5,1.0,9,1.0,52,{fontFace:'Arial',bold:true,color:t.bg});txt(s,'让文档示例，拿得出当前运行证据',.5,2.35,9,.65,29,{bold:true,color:t.bg});txt(s,'文档可检索  /  示例真实执行  /  SDK 与索引自动检查',.5,3.35,9,.4,18,{color:t.light});rect(s,.5,4.4,8.9,.5,t.light);txt(s,'仓颉生态创新开发挑战赛 · 课题 9 · 决赛路演版',.7,4.52,8.5,.24,13);txt(s,'主讲计划 7分20秒（含90秒网页）  ·  源码 R2 / 075aeb3',.5,.48,9,.25,12,{color:t.light});
notes(s,content[0]);return s;
}
module.exports={createSlide,slideConfig};
