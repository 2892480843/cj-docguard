const {txt,rect,box,base,shot,metric,notes}=require('./theme');
const content=require('../content.json').slides;
const slideConfig={type:'content',index:8};
function createSlide(p,t){
const s=base(p,8,'效果用证据量化，失败和边界不隐藏','07 / R2最终实测 · 各数字口径分开','证据：VERIFICATION.md · integration-tests.txt · live-history-pressure.json');metric(s,'123','集成测试全通过 · 零跳过',.65,1.78,4.1);metric(s,'20','两版SDK合计的原生测试程序',5.3,1.78,4.1);metric(s,'655','实际保留的历史记录',.65,3.1,4.1);metric(s,'120 / 120','12并发 × 10轮读取成功 · 文件未变',5.3,3.1,4.1);rect(s,.5,4.6,8.95,.4,t.light);txt(s,'另有约20MB结构化归档与断连清理回归；测试数量不是覆盖率。',.68,4.69,8.6,.23,14,{bold:true});
notes(s,content[7]);return s;
}
module.exports={createSlide,slideConfig};
