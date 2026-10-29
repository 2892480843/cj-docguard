#!/usr/bin/env node
const pptxgen=require('pptxgenjs'),path=require('node:path');const {theme}=require('./theme');require('./write-script').writeScript();
async function build(count,suffix){const p=new pptxgen();p.defineLayout({name:'CJ',width:10,height:5.625});p.layout='CJ';p.title='CJ-DocGuard 决赛路演（主讲含90秒网页演示）';p.author='CJ-DocGuard';p.subject='项目级API文档生成及测试 / R2 075aeb3';p.lang='zh-CN';p.company='CJ-DocGuard';for(let n=1;n<=count;n++)require('./slide-'+String(n).padStart(2,'0')).createSlide(p,theme);await p.writeFile({fileName:path.join(__dirname,'..','CJ-DocGuard-决赛路演-'+suffix+'.pptx')});}
(async()=>{await build(10,'主讲10页');await build(14,'含备查14页')})().catch(e=>{console.error(e);process.exitCode=1});
