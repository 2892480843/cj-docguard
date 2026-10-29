const {txt,rect,box,base}=require('./theme');
const slideConfig={type:'cover',index:1};
function createSlide(p,t){const s=p.addSlide();s.background={color:t.primary};txt(s,'CANGJIE · PROJECT API DOCS',.5,.45,9,.35,14,{color:t.bg,charSpacing:1.5});txt(s,'CJ-DocGuard',.5,1.2,9,1.0,54,{color:t.bg,bold:true,fontFace:'Arial'});txt(s,'让 API 文档里的示例，拿得出运行证据',.5,2.55,9,.6,26,{color:t.bg,bold:true});txt(s,'仓颉原生工作台  /  双 SDK 检查  /  当前证据准入',.5,3.45,9,.4,17,{color:t.light});rect(s,.5,4.35,8.7,.53,t.light);txt(s,'课题 #9：项目级 API 文档生成及测试  ·  决赛迭代 2026-10-29',.7,4.5,8.3,.2,12);s.addNotes('约35秒。先讲价值：文档、示例与SDK版本容易脱节。作品用真实编译运行和当前输入身份连接三者。随后直接展示可操作的网页工作台。');
}
module.exports={createSlide,slideConfig};
