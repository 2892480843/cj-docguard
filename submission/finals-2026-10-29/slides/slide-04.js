const {txt,rect,box,base}=require('./theme');
const slideConfig={type:'content',index:4};
function createSlide(p,t){const s=base(p,4,'一次成功，必须属于当前输入','03 / 为什么能信','源码：src/evidence.cj · src/bindings.cj · src/report.cj · src/export.cj');const labels=['冻结输入','真实执行','断言检查','证据准入'];const bodies=['源码 / 配置摘要\nSDK / 平台身份','编译 → 运行\n有界日志与超时','输出与退出码\n编译型明确区分','最新记录优先\n唯一 API 身份'];for(let i=0;i<4;i++){box(s,.5+i*2.3,1.9,2.1,2.2,labels[i],bodies[i]);if(i<3)txt(s,'→',2.62+i*2.3,2.75,.18,.3,16,{bold:true});}rect(s,.5,4.42,8.95,.49,t.accent);txt(s,'源码变化 → STALE；最新断言失败 → 拒绝旧成功；历史快照 → 不取得当前资格',.65,4.58,8.65,.2,13,{bold:true});s.addNotes('约45秒。关键设计不是展示绿色状态，而是拒绝不属于当前输入的旧证据。源码和配置、SDK与平台都进入身份。只编译样例不会伪装成运行通过。查询和导出共用准入规则，最新失败不能回退到历史成功。');
}
module.exports={createSlide,slideConfig};
