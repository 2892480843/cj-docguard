const {txt,rect,box,base,shot,metric,notes}=require('./theme');
const content=require('../content.json').slides;
const slideConfig={type:'content',index:7};
function createSlide(p,t){
const s=base(p,7,'技术三：检查真实链接，绑定唯一接口','06 / 三项反例驱动修复','回归：native_links.cj / native_index.cj / test_bindings.py / test_native_workbench.py');box(s,.5,1.82,4.25,2.91,'实际链接与完整标题','实际HTML href / src按索引位置解析\n多行标题累积完整段落\n97条解析断言＋13条实际索引断言\n每个SDK独立执行');box(s,5.2,1.82,4.25,2.91,'示例归属只认唯一身份','read → 重名歧义，拒绝\nFirst.read → 唯一成员\n重载 → 精确symbol_id\n报告、查询、导出共用身份');txt(s,'外链离线保持UNVERIFIED；登记关联不等于自动证明完整语义覆盖。',.5,4.88,8.95,.23,12,{bold:true});
notes(s,content[6]);return s;
}
module.exports={createSlide,slideConfig};
