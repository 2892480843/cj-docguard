const {txt,rect,base}=require('./theme');
const slideConfig={type:'content',index:14};
function createSlide(p,t){
 const s=base(p,14,'复现条件与 R2 大历史响应设计','备查 D / 工具链、身份和内存边界','证据：评委运行指南 · SOURCE.json · PUBLIC-CLONE.md · workbench_native/');
 rect(s,.5,1.83,4.25,1.29,t.light);txt(s,'已验证环境',.72,2.02,3.81,.32,21,{bold:true});txt(s,'macOS arm64 · 两版真实 SDK\n1.1.3 / 1.2.0 + 兼容系统 SDK',.72,2.56,3.81,.49,15);
 rect(s,5.2,1.83,4.25,1.29,t.light);txt(s,'源码与材料分别记身份',5.42,2.02,3.81,.32,20,{bold:true});txt(s,'075aeb3 · R2 功能源码\n材料回执不改变 167 项源码',5.42,2.56,3.81,.49,15);
 rect(s,.5,3.44,8.95,1.19,t.primary);txt(s,'完整报告 → 临时 JSON 文件 → 64KiB 分块发送',.72,3.65,8.51,.31,21,{bold:true,color:t.bg});txt(s,'响应串行化限制峰值；成功、失败与断连均清理临时文件。',.72,4.17,8.51,.25,16,{color:t.bg});
 txt(s,'显式传入系统 SDK；预装环境复现不等于新系统安装验收。',.5,4.79,8.95,.22,15);
 s.addNotes('备查页，不计入主讲时间。固定功能源码为075aeb38fc32d46680f312e8ac3647a0977e1366、标签finals-source-20261029-r2；后续材料提交与源码提交分别记录。回执克隆的是当时main ed764fe，167项功能源码摘要与标签相同。Mac端需要仓颉SDK和兼容Apple系统SDK两套依赖；本机旧仓颉链接器与默认系统SDK的TAPI格式不兼容，显式登记可用的15.4路径。R2修正审计脚本白名单遗漏，确保CJ_DOCGUARD_SYSTEM_SDKROOT传入原生进程。大历史先限制并发驻留，随后消除单份完整JSON字符串与字节数组的峰值副本：report/history使用临时文件流式序列化和64KiB分块响应，接口与历史字段不变，正常或断连均清理。约20MB结构化归档及真实655条历史120次读取已有验证，但这不是无限报告大小、压力吞吐基准或完整新系统安装承诺。');
}
module.exports={createSlide,slideConfig};
