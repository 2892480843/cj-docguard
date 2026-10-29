const {txt,rect,base}=require('./theme');
const slideConfig={type:'content',index:13};
function createSlide(p,t){
 const s=base(p,13,'状态不能混用，旧成功不能兜底','备查 C / 准入规则与失败边界','证据：src/evidence.cj · src/engine.cj · tests/test_cli.py');
 const rows=[['RUN_VERIFIED + CURRENT','仍须唯一绑定、精确环境与完整日志'],['COMPILE_ONLY','只说明编译通过，不作为运行证据'],['STALE','输入或环境变化，当前资格失效'],['ASSERTION_FAILED','最新断言失败，不回退旧成功'],['FROZEN（历史）','保留记录，不重新取得当前资格'],['UNVERIFIED（链接）','没有确认可访问，不能计作通过']];
 for(let i=0;i<rows.length;i++){const y=1.83+i*.45;rect(s,.5,y,8.95,.4,i%2===0?t.light:t.bg);txt(s,rows[i][0],.65,y+.095,3.65,.22,15,{bold:true,fontFace:'Arial'});txt(s,rows[i][1],4.35,y+.095,4.9,.22,15);}
 txt(s,'限时、限日志、清理进程组；可信本地项目，非 OS 安全沙箱。',.5,4.73,8.95,.25,15,{bold:true});
 s.addNotes('备查页，不计入主讲时间。状态来自不同维度：RUN_VERIFIED是记录的运行状态，CURRENT是输入与环境当前性，eligible还结合完整日志、必需断言、唯一API绑定等准入条件。只有标签绿色不够。仅编译可以在自身类型的严格检查中成立，但不能通过运行示例查询和导出。最新尝试按序列选择；最新失败、待执行或输入改变时不能退回旧成功。冻结历史作为审计档案保留。链接UNVERIFIED是另一域，离线外链没有被发起网络访问，不能理解成外链已确认有效。资源监督器限制时间、输出并清理进程组，却不隔离文件系统、网络和主机权限；因此只用于维护者审核并显式授权的可信本地项目。');
}
module.exports={createSlide,slideConfig};
