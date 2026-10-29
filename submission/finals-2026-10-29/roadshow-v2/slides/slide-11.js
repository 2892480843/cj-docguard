const {txt,rect,base}=require('./theme');
const slideConfig={type:'content',index:11};
function createSlide(p,t){
 const s=base(p,11,'声明提取与证据绑定，各有明确边界','备查 A / 解析与关联','证据：src/extractor.cj · src/bindings.cj · tests/test_bindings.py');
 const xs=[.5,3.6,6.7],titles=['std.ast 解析','完整符号目录','唯一 ID 绑定'];
 for(let i=0;i<3;i++){rect(s,xs[i],1.83,2.8,.64,t.primary);txt(s,titles[i],xs[i]+.15,2.02,2.5,.25,18,{bold:true,color:t.bg});if(i<2)txt(s,'→',xs[i]+2.82,2.02,.25,.3,20,{bold:true});}
 rect(s,.5,2.83,4.25,1.91,t.light);txt(s,'可以证明什么',.72,3.04,3.81,.36,21,{bold:true});txt(s,'声明、参数、返回类型与位置\n短名仅在全局唯一时绑定\n重载需要精确符号 ID',.72,3.66,3.81,.86,16,{breakLine:false});
 rect(s,5.2,2.83,4.25,1.91,t.light);txt(s,'不自动推断什么',5.42,3.04,3.81,.36,21,{bold:true});txt(s,'不是完整语言语义分析\n不构建完整调用图\n登记关联不等于调用覆盖证明',5.42,3.66,3.81,.86,16);
 s.addNotes('备查页，不计入主讲时间。公共声明使用仓颉 std.ast（抽象语法树，编译器把源码结构化后的树）解析，再结合源码位置、注释和支持范围形成目录。示例先在完整目录中解析引用：短名、包名与所属类型限定名只有匹配唯一符号才接受；同一所属类型的重载通常要使用精确 s-ID。结果保存 symbol_id 和 binding_status，报告、查询和导出依照同一身份。未知、歧义和历史缺身份不能在显示时重新绑定取得资格。必须明确：这解决了“把 First 的例子挂到 Second”这一关联错误；当前没有通过完整语义调用图证明每个登记示例真的调用了所声明 API。可信维护者仍需审核登记内容和断言。');
}
module.exports={createSlide,slideConfig};
