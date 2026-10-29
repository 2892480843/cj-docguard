const {txt,rect,box,base}=require('./theme');
const slideConfig={type:'content',index:8};
function createSlide(p,t){const s=base(p,8,'网页演示：从接口检索到独立重建','06 / 现场操作主线','操作提纲：docs/finals-demo-runbook-2026-10-29.md；原生服务：scripts/workbench.sh');const items=[['01','检索接口','47 个公共符号\n声明、参数、返回及示例'],['02','查看矩阵','28 格：26 运行验证\n2 仅编译，展示断言值'],['03','检查与失效','链接筛选、详情定位\n源码改变后旧证据失效'],['04','查询与导出','精确 SDK / 平台准入\n导出包运行 build.sh']];for(let i=0;i<4;i++){const x=.5+i*2.3;txt(s,items[i][0],x,1.85,2,.6,40,{bold:true,color:t.accent});box(s,x,2.6,2.1,1.95,items[i][1],items[i][2]);}txt(s,'另外可操作：项目登记与配置、源码编辑、任务取消、锁恢复、历史快照及报告对比。',.5,4.78,9,.25,12);s.addNotes('约45秒。这页作为实际浏览器演示导航，不是界面截图。准备阶段真实验证和现场点击必须区分。通过接口搜索展示add，再看矩阵、原版修复版对照、链接检查和源码改变后的证据失效。最后查看精确SDK查询与导出包；只有实际运行build.sh才称现场重建成功。');
}
module.exports={createSlide,slideConfig};
