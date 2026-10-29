const {txt,rect,box,base,shot,metric,notes}=require('./theme');
const content=require('../content.json').slides;
const slideConfig={type:'content',index:4};
function createSlide(p,t){
const s=base(p,4,'技术一：区分曾经成功与当前可用','03 / 证据准入','源码：src/evidence.cj · engine.cj · bindings.cj · export.cj；16步实测见live-workflow.txt');const a=[['输入身份','源码 / 配置\nSDK / 平台'],['真实执行','编译 → 运行\n日志与退出码'],['断言检查','输出 / 退出码\n仅编译单列'],['统一准入','精确接口身份\n查询、导出共用']];for(let i=0;i<4;i++){box(s,.5+i*2.3,1.88,2.1,1.92,...a[i]);if(i<3)txt(s,'→',2.62+i*2.3,2.6,.18,.25,16,{bold:true});}rect(s,.5,4.12,8.95,.78,t.accent);txt(s,'源码变化 → STALE（过期）\n最新失败 → 拒绝历史成功；历史保留但不取得当前资格',.7,4.25,8.55,.52,17,{bold:true});
notes(s,content[3]);return s;
}
module.exports={createSlide,slideConfig};
