const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const source=readFileSync('app/javascript/controllers/shelf_image.js','utf8').replace(/export /g,'')
const {portraitShelfLayout,SHELF_THEMES,shelfImageAltText}=new Function(source+';return {portraitShelfLayout,SHELF_THEMES,shelfImageAltText}')()
test('all portrait layouts keep artwork and readable text outside Story chrome',()=>{
 for(const layout of ['exhibition','reading','collector'])for(let n=0;n<=5;n++){
  const boxes=portraitShelfLayout(n,layout);assert.equal(boxes.length,n)
  for(const box of boxes){
   assert.ok(box.x>=72 && box.x+box.width<=1008,`${layout}/${n}: horizontal cover safety`)
   assert.ok(box.y>=250 && box.y+box.height<1550,`${layout}/${n}: vertical cover safety`)
   assert.ok(box.labelX>=72 && box.labelX+box.labelWidth<=1008,`${layout}/${n}: label width`)
   assert.ok(box.labelY>=250 && box.labelY+box.font*1.3*(box.labelLines-1)<=1570,`${layout}/${n}: lower label safety`)
  }
 }
})
test('Telly and Facet palettes are distinct and sparse-image alt text names only actual picks',()=>{
 assert.notEqual(SHELF_THEMES.telly.bg,SHELF_THEMES.facet.bg)
 const alt=shelfImageAltText({picks:[{title:'Synthetic sample'}],overview:false,category:'Books',theme:'telly',format:'portrait',handle:'demo',layout:'reading'})
 assert.match(alt,/reading layout/);assert.match(alt,/Synthetic sample/);assert.doesNotMatch(alt,/Not picked yet|2\./)
})

test('every shelf palette meets AA body and secondary text contrast',()=>{
 const luminance=hex=>{const c=[0,2,4].map(i=>parseInt(hex.slice(i+1,i+3),16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4);return c[0]*.2126+c[1]*.7152+c[2]*.0722}
 for(const [name,theme] of Object.entries(SHELF_THEMES))for(const role of ['text','muted']){
  const [low,high]=[luminance(theme.bg),luminance(theme[role])].sort((a,b)=>a-b)
  assert.ok((high+.05)/(low+.05)>=4.5,`${name} ${role} contrast`)
 }
})
