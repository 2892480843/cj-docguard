const {txt,rect,box,base}=require('./theme');
const slideConfig={type:'content',index:2};
function createSlide(p,t){const s=base(p,2,'赛题交付，形成网页操作闭环','01 / 要解决什么','依据：用户提供课题 #9 任务截图；docs/finals-requirement-evidence-2026-10-29.md');box(s,.5,1.85,2.8,2.45,'结构化 API 文档','声明与源码位置\n参数、返回类型\n示例源码与接口搜索');box(s,3.6,1.85,2.8,2.45,'示例正确性验证','实际编译与运行\n输出 / 退出码断言\n期望值、实际值、日志');box(s,6.7,1.85,2.8,2.45,'SDK 与索引检查','1.1.3 / 1.2.0 矩阵\n文档和实际索引链接\n自动状态、原因与定位');txt(s,'登记项目  →  诊断  →  索引  →  验证  →  检查  →  查询 / 导出',.5,4.57,9,.35,18,{bold:true});s.addNotes('约40秒。用三列对应赛题三项交付，避免泛泛描述平台。每项都有网页入口和自动检查产物。网页并非静态说明页，后续演示会展示真实任务和错误结果。');
}
module.exports={createSlide,slideConfig};
