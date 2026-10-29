const {txt,rect,box,base}=require('./theme');
const slideConfig={type:'content',index:5};
function createSlide(p,t){const s=base(p,5,'真实库：保留失败，再验证修复','04 / 价值与实际效果','固定 leven4cj：da69d981…；修复说明：docs/real-library-unicode-repair-2026-10-29.md');rect(s,.5,1.8,4.2,1.5,t.accent);txt(s,'原版 36 / 40',.73,2.03,3.8,.6,34,{bold:true});txt(s,'4 格 Unicode 空串断言失败，保留原样',.73,2.82,3.8,.23,13);rect(s,5.25,1.8,4.2,1.5,t.light);txt(s,'修复副本 40 / 40',5.48,2.03,3.8,.6,32,{bold:true});txt(s,'显式应用补丁，两个 SDK 使用相同断言',5.48,2.82,3.8,.23,13);txt(s,'根因：两个空串分支使用字节数；其余路径按 Unicode 码点计数。',.5,3.65,9,.35,19,{bold:true});rect(s,.5,4.18,8.95,.66,t.light);txt(s,'String.size  →  String.toRuneArray().size',.72,4.39,8.5,.25,18,{fontFace:'Arial',bold:true});s.addNotes('约55秒。例子是空串到汉字你：原版输出3字节，登记预期是1个码点。两个调用乘两个SDK产生4格失败。仅改两个空串分支，不改断言、不改锁定缓存；副本记录补丁、前后摘要与许可证。这是码点语义，未宣称处理字形簇或Unicode规范化，也未声称上游接受补丁。');
}
module.exports={createSlide,slideConfig};
