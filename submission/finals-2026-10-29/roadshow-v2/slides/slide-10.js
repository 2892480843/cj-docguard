const {txt,rect,box,base,shot,metric,notes}=require('./theme');
const content=require('../content.json').slides;
const slideConfig={type:'summary',index:10};
function createSlide(p,t){
const s=base(p,10,'让维护者与评委，能够重复检查','09 / 价值与边界 · 7分20秒结束','公开入口：atomgit.com/c2892480843s/cj-docguard；备查页11–14仅追问时使用');box(s,.5,1.85,4.25,2.58,'交付价值','文档可检索、示例可验证\n版本和链接能自动检查\n源码变化后拒绝旧证据\n公开克隆能够重复运行');box(s,5.2,1.85,4.25,2.58,'当前实测范围','macOS arm64 / 两版SDK\n审核后登记的可信本地项目\n外链离线未验证\n不等同于OS安全沙箱');txt(s,'后续：扩展平台回归与更复杂项目输入。谢谢各位评委。',.5,4.68,8.95,.3,19,{bold:true});
notes(s,content[9]);return s;
}
module.exports={createSlide,slideConfig};
