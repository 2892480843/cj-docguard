const {txt,rect,box,base}=require('./theme');
const slideConfig={type:'summary',index:10};
function createSlide(p,t){const s=base(p,10,'交付有证据，边界说清楚','08 / 可复现的项目级文档验证','公开源码：atomgit.com/c2892480843s/cj-docguard  ·  决赛验证记录见仓库材料入口');box(s,.5,1.85,4.25,2.5,'本轮交付','仓颉核心 + 仓颉本地服务\n网页完成核心验证工作流\n三项功能修复与回归测试\n固定源码、指南与验证记录');box(s,5.2,1.85,4.25,2.5,'适用边界','macOS arm64；两版实际 SDK\n可信本地、登记后的项目\n外链离线未验证\n非完整语言语义 / CommonMark');txt(s,'目标：让库维护者与评审能重复检查，而不是只相信一次展示。',.5,4.65,9,.35,19,{bold:true});s.addNotes('约35秒。总结价值：帮助库维护者对文档示例与SDK对应关系提供可重复检查的运行证据。进程监督不是OS安全沙箱，不声称其他平台完整回归、模型效果提升或上游采用。正式比赛时间与材料提交以后续通知为准，本轮源码同步不等于赛事正式提交。');
}
module.exports={createSlide,slideConfig};
