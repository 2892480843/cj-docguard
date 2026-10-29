const {txt,rect,box,base,shot,metric,notes}=require('./theme');
const content=require('../content.json').slides;
const slideConfig={type:'content',index:9};
function createSlide(p,t){
const s=base(p,9,'交给评委：固定源码、干净克隆、独立重建','08 / 公开交付','AtomGit主仓库 / GitHub镜像；运行条件与克隆回执：judge-quickstart.md / PUBLIC-CLONE.md');rect(s,.5,1.83,4.4,2.99,t.primary);txt(s,'固定功能源码',.73,2.05,3.95,.35,19,{color:t.bg,bold:true});txt(s,'075aeb3',.73,2.7,3.95,.6,36,{color:t.bg,fontFace:'Arial',bold:true});txt(s,'finals-source-20261029-r2',.73,3.57,3.95,.3,16,{color:t.light,fontFace:'Arial'});txt(s,'源码与后续材料提交分别记录',.73,4.2,3.95,.28,14,{color:t.bg});txt(s,'公开克隆 → 登记已安装SDK\n构建启动 → 查询 / 导出 / 重建',5.25,1.87,4.1,.65,18,{bold:true});metric(s,'42','两版SDK分别导出并重建的实际输出',5.25,2.85,4.1);txt(s,'新缓存真实库：原版36/40，修复40/40\n无预存build、报告或第三方缓存',5.25,4.26,4.1,.6,16);
notes(s,content[8]);return s;
}
module.exports={createSlide,slideConfig};
