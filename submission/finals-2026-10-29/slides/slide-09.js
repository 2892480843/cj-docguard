const {txt,rect,box,base}=require('./theme');
const slideConfig={type:'content',index:9};
function createSlide(p,t){const s=base(p,9,'评委可从公开源码复现固定版本','07 / 完整交付','评委指南：docs/judge-quickstart.md；精确源码和验证身份：submission/finals-2026-10-29/');rect(s,.5,1.8,8.95,1.25,t.primary);txt(s,'finals-source-20261029-r2',.72,2.04,8.5,.5,30,{fontFace:'Arial',color:t.bg,bold:true});txt(s,'源码标签；精确提交与后续证据提交分别记录',.72,2.67,8.5,.2,12,{color:t.bg});txt(s,'克隆 → 登记真实 SDK → 构建并启动 → 浏览器操作',.5,3.4,9,.4,22,{bold:true});rect(s,.5,4.1,8.95,.68,t.light);txt(s,'bash scripts/build_workbench.sh\nbash scripts/workbench.sh --port 8765',.72,4.25,8.5,.42,15,{fontFace:'Arial'});s.addNotes('约40秒。主仓库AtomGit，GitHub镜像。按指南登记真实1.1.3和1.2.0工具链与兼容Apple系统SDK。最新版功能源码使用finals-source-20261029-r2；旧finals-source-20261029标签保留为历史，不作为本轮纠正版本入口。记录源码冻结身份和后续证据提交，避免自引用摘要。干净克隆验证结果以发布目录回执为准；没有将本机预装工具链说成全新操作系统在线安装验收。');
}
module.exports={createSlide,slideConfig};
