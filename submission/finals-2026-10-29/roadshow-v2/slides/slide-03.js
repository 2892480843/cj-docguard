const {txt,rect,box,base,shot,metric,notes}=require('./theme');
const content=require('../content.json').slides;
const slideConfig={type:'content',index:3};
function createSlide(p,t){
const s=base(p,3,'现场演示：失败保留，修复可核对','02 / 90秒网页 · 已含在7分20秒内','截图局部来自实际断言弹窗；原图及任务结果见evidence/与PUBLIC-CLONE.md');txt(s,'原版 36/40：期望1，实际3',.5,1.65,4.25,.36,21,{bold:true});txt(s,'修复 40/40：期望1，实际1',5.2,1.65,4.25,.36,21,{bold:true});shot(s,'web-unicode-original.png',.5,2.16,4.25,[.14,.39,.72,.22]);shot(s,'web-unicode-fixed.png',5.2,2.16,4.25,[.14,.39,.72,.22]);rect(s,.5,4.62,8.95,.38,t.light);txt(s,'原版断言 → 修复副本 → 链接FAIL筛选；每次等待最多8秒',.66,4.7,8.6,.22,15,{bold:true});
notes(s,content[2]);return s;
}
module.exports={createSlide,slideConfig};
