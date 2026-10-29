const {txt,rect,box,base,shot,metric,notes}=require('./theme');
const content=require('../content.json').slides;
const slideConfig={type:'content',index:5};
function createSlide(p,t){
const s=base(p,5,'技术二：仓颉承担核心与本地网页服务','04 / 从浏览器到真实工具链','源码：web/ · workbench_native/ · src/；监督器：scripts/runner.c');box(s,.5,1.85,2.8,1.74,'浏览器工作台','HTML / CSS / JavaScript\n检索、矩阵、源码、导出');box(s,3.6,1.85,2.8,1.74,'仓颉 HTTP 服务','本机请求与原生任务\n完整报告分块发送');box(s,6.7,1.85,2.8,1.74,'仓颉核心','声明提取、验证编排\n断言、准入与报告');txt(s,'→',3.33,2.55,.25,.3,19);txt(s,'→',6.43,2.55,.25,.3,19);rect(s,.5,3.94,8.95,.57,t.light);txt(s,'仓颉 SDK 1.1.3 / 1.2.0：实际编译、运行、校验输出',.7,4.09,8.55,.25,19,{bold:true});txt(s,'C：进程组监督 / 信号桥；Bash：构建启动；Python：测试、安装辅助与只读协议适配。',.5,4.68,9,.3,13);
notes(s,content[4]);return s;
}
module.exports={createSlide,slideConfig};
