const {txt,rect,box,base,shot,metric,notes}=require('./theme');
const content=require('../content.json').slides;
const slideConfig={type:'content',index:2};
function createSlide(p,t){
const s=base(p,2,'先看效果：接口、示例和版本一起查','01 / 实际工作台','真实截图：evidence/web-api.png；验证：evidence/live-summary.json');shot(s,'web-api.png',.48,1.6,5.1,[.21,.33,.76,.58]);metric(s,'47','公共符号\n声明、参数、返回、示例',6.15,1.75,3.25);metric(s,'26 + 2','运行验证 + 仅编译\n14例 × 2版SDK = 28格',6.15,3.2,3.25);txt(s,'截图为真实报告快照；当前资格以原生检查/查询为准。',6.15,4.62,3.25,.38,11,{valign:'top'});
notes(s,content[1]);return s;
}
module.exports={createSlide,slideConfig};
