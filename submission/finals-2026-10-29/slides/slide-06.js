const {txt,rect,box,base}=require('./theme');
const slideConfig={type:'content',index:6};
function createSlide(p,t){const s=base(p,6,'实际索引与多行标题，都进入检查','05 / 初赛后改进：F01 + F02','回归：tests/native_index.cj · tests/native_links.cj · tests/test_cli.py · tests/test_native_workbench.py');box(s,.5,1.8,6.55,1.3,'F01  实际 HTML URL 扫描','href / src 按实际索引文件位置解析；保留预期 API 锚点检查。');box(s,.5,3.37,6.55,1.3,'F02  完整 Setext 标题段落','多行标题不丢首行；覆盖容器、边界、代码屏蔽及重复标题。');rect(s,7.4,1.8,2.05,2.87,t.primary);txt(s,'97',7.62,2.03,1.6,.6,40,{color:t.bg,bold:true});txt(s,'链接解析断言 / SDK',7.62,2.79,1.65,.4,12,{color:t.bg});txt(s,'13',7.62,3.34,1.6,.6,40,{color:t.bg,bold:true});txt(s,'实际索引断言 / SDK',7.62,4.12,1.65,.3,12,{color:t.bg});s.addNotes('约50秒。修复前只合成预期API锚点，遗漏索引里的真实坏href；现在实际URL与预期锚点两组都保留。多行Setext标题现在用完整段落生成锚点，错误短锚点不会误通过。远程链接离线未验证；base、重复属性、候选集合无法可靠解释时明确未验证，不计为通过。两个实际SDK分别跑97与13条原生断言。');
}
module.exports={createSlide,slideConfig};
