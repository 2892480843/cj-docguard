const {txt,rect,box,base}=require('./theme');
const slideConfig={type:'content',index:7};
function createSlide(p,t){const s=base(p,7,'示例，只能绑定唯一 API 身份','05 / 初赛后改进：F03','源码：src/bindings.cj；回归：tests/native_bindings.cj · tests/test_bindings.py');rect(s,.5,1.82,4.25,2.85,t.light);txt(s,'同名 ≠ 同一个接口',.72,2.04,3.8,.45,24,{bold:true});txt(s,'First.read()  →  1\nSecond.read() →  2',.72,2.85,3.8,.85,23,{fontFace:'Arial'});txt(s,'只调用 First 的示例，不能证明 Second。',.72,4.15,3.8,.25,13,{bold:true});box(s,5.2,1.82,4.25,2.85,'统一解析，统一准入','先收集完整符号目录\n短名只在全局唯一时绑定\n所属类型 / 限定名 / 精确 ID\n未知与歧义：明确拒绝');s.addNotes('约45秒。原问题不是断言伪造，而是示例错误挂到同名成员。现在示例记录持久化准确symbol_id与binding_status，报告、查询、导出使用同一身份。重载需要精确ID，历史缺身份记录不能靠显示层重新绑定取得资格。回归覆盖跨文件、不同所属对象、重载与历史记录。');
}
module.exports={createSlide,slideConfig};
