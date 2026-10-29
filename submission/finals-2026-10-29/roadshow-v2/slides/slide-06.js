const {txt,rect,box,base,shot,metric,notes}=require('./theme');
const content=require('../content.json').slides;
const slideConfig={type:'content',index:6};
function createSlide(p,t){
const s=base(p,6,'初赛后：从命令行作品到可复现工作台','05 / 对照改进 · 每项都有验收入口','初赛基线与迭代过程：docs/finals-iteration-2026-10-29.md；R2见SOURCE.json');txt(s,'维度',.5,1.65,1.3,.28,15,{bold:true});txt(s,'初赛基础',2.02,1.65,2.75,.28,15,{bold:true});txt(s,'决赛新增 / 深化',5.05,1.65,4.4,.28,15,{bold:true});const rows=[['使用入口','CLI 与静态文档','仓颉网页：源码、矩阵、任务、导出'],['可信校验','基础示例与版本检查','真实链接、完整标题、唯一绑定'],['交付复现','初赛材料归档','固定源码＋逐项证据＋公开克隆回执']];rows.forEach((r,i)=>{const y=2.12+i*.94;rect(s,.5,y,8.95,.73,t.light);txt(s,r[0],.65,y+.18,1.2,.3,18,{bold:true});txt(s,r[1],2.02,y+.15,2.75,.4,17);txt(s,r[2],5.05,y+.12,4.12,.46,17);});txt(s,'本轮还补齐：Apple系统SDK传递、大历史流式响应、断连清理与回归。',.5,4.92,8.95,.18,12);
notes(s,content[5]);return s;
}
module.exports={createSlide,slideConfig};
