#!/usr/bin/env node
// npm install pptxgenjs; node compile.js. Each slide module is synchronous.
const pptxgen=require('pptxgenjs');const path=require('node:path');const {theme}=require('./theme');
const pres=new pptxgen();pres.defineLayout({name:'CJ',width:10,height:5.625});pres.layout='CJ';pres.author='CJ-DocGuard';pres.subject='仓颉生态创新开发挑战赛课题 #9';pres.title='CJ-DocGuard 决赛答辩';pres.company='CJ-DocGuard';pres.lang='zh-CN';
for(let n=1;n<=10;n++)require('./slide-'+String(n).padStart(2,'0')).createSlide(pres,theme);
pres.writeFile({fileName:path.join(__dirname,'..','CJ-DocGuard-决赛答辩-20261029.pptx')});
