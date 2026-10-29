const {txt,rect,box,base}=require('./theme');
const slideConfig={type:'content',index:3};
function createSlide(p,t){const s=base(p,3,'核心与本地服务，都由仓颉驱动','02 / 如何实现','源码：src/ · workbench_native/ · web/ · scripts/native_env.sh');box(s,.5,1.85,2.65,1.65,'浏览器工作台','HTML / CSS / JavaScript');box(s,3.65,1.85,2.65,1.65,'仓颉 HTTP 服务','本地请求与任务\n大历史响应有界并发');box(s,6.8,1.85,2.65,1.65,'仓颉核心','提取、验证、准入、报告');txt(s,'→',3.18,2.43,.4,.4,25,{bold:true});txt(s,'→',6.33,2.43,.4,.4,25,{bold:true});rect(s,.5,3.85,8.95,.8,t.light);txt(s,'真实 SDK 1.1.3 / 1.2.0   ·   C 进程监督 / 信号桥   ·   Bash 构建与启动',.7,4.08,8.55,.3,17,{bold:true});txt(s,'Python：测试、安装辅助与只读 MCP（模型上下文协议）适配；不提供正式 HTTP 服务。',.5,4.8,9,.2,11);s.addNotes('约45秒。回答是否使用仓颉：CLI核心和HTTP服务均是仓颉；前端仍是浏览器标准技术。C仅承担进程监督和信号桥。Python只在辅助、测试和协议适配中，正式服务不依赖Python HTTP运行时。可信本地代码执行不等于操作系统安全沙箱。新增大历史响应保护：请求读取保持并行，响应构造与发送串行化，避免多个大历史JSON同时解析造成内存峰值；保留完整历史，客户端上限16、发送超时5秒，不承诺无限单报告。并发回归结果以本轮最终验证记录为准。');
}
module.exports={createSlide,slideConfig};
