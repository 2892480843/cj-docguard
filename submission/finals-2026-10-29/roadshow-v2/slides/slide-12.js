const {txt,rect,base}=require('./theme');
const slideConfig={type:'content',index:12};
function createSlide(p,t){
 const s=base(p,12,'四个失败格，来自两个调用 × 两个 SDK','备查 B / Unicode 根因与补丁','证据：Unicode 修复记录 · integrations/leven4cj/patches/manifest.json');
 const x=[.5,4.05,5.85,7.65],w=[3.55,1.8,1.8,1.8],headers=['登记例','1.1.3 原版','1.2.0 原版','两版修复'];
 for(let i=0;i<4;i++){rect(s,x[i],1.83,w[i],.48,t.primary);txt(s,headers[i],x[i]+.12,1.97,w[i]-.24,.22,15,{bold:true,color:t.bg});}
 const rows=[['unicode-empty：空串 → “你”','3','3','1'],['emoji-empty：表情 → 空串','4','4','1']];
 for(let r=0;r<2;r++)for(let c=0;c<4;c++){rect(s,x[c],2.41+r*.63,w[c],.54,r===0?t.light:t.bg);txt(s,rows[r][c],x[c]+.12,2.57+r*.63,w[c]-.24,.25,c===0?15:20,{bold:c>0});}
 rect(s,.5,3.92,8.95,.85,t.light);txt(s,'两个空串分支：字节数 → Unicode 码点数',.72,4.08,8.51,.29,20,{bold:true});txt(s,'断言与锁定缓存不改；补丁副本标明 source_modified=true',.72,4.48,8.51,.23,15);
 s.addNotes('备查页，不计入主讲时间。固定 leven4cj 提交 da69d981027b9fcbe12d09cfbb275b4ce8acc91d。unicode-empty 为 leven("", "你")，原版两个 SDK 都输出3，登记预期1；emoji-empty 为 leven("😀", "")，两个 SDK 都输出4，预期1。非空路径转为 Rune 数组，而空串分支直接用 String.size，单位不一致。显式补丁只把两个 return 分支改为 toRuneArray().size；没有修改原有20个示例的字节和断言，也不改锁定缓存。原版36/40有效与4失败继续保留，显式副本40/40。补丁前后和补丁本身都有 SHA-256，副本保留 Apache-2.0 许可及 source_modified=true。语义是码点，不是字形簇；例如组合字符与预组合字符没有自动规范化。修复不等于上游接受或采用。');
}
module.exports={createSlide,slideConfig};
