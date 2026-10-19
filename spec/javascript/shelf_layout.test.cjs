const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const source=readFileSync('app/javascript/controllers/shelf_image.js','utf8').replace(/export /g,'')
const {portraitShelfLayout,SHELF_THEMES,shelfImageAltText,shelfImageHeading}=new Function(source+';return {portraitShelfLayout,SHELF_THEMES,shelfImageAltText,shelfImageHeading}')()
test('all portrait layouts keep artwork and readable text outside Story chrome',()=>{
 for(const layout of ['exhibition','reading','collector','mixtape'])for(let n=0;n<=5;n++){
  const boxes=portraitShelfLayout(n,layout);assert.equal(boxes.length,n)
  for(const box of boxes){
   assert.ok(box.x>=72 && box.x+box.width<=1008,`${layout}/${n}: horizontal cover safety`)
   assert.ok(box.y>=250 && box.y+box.height<1550,`${layout}/${n}: vertical cover safety`)
   assert.ok(box.labelX>=72 && box.labelX+box.labelWidth<=1008,`${layout}/${n}: label width`)
   assert.ok(box.labelY>=250 && box.labelY+32+box.font*1.3*(box.labelLines-1)<=1570,`${layout}/${n}: lower label safety`)
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
 for(const [name,theme] of Object.entries(SHELF_THEMES))for(const role of ['text','muted','accent']){
  const [low,high]=[luminance(theme.bg),luminance(theme[role])].sort((a,b)=>a-b)
  assert.ok((high+.05)/(low+.05)>=4.5,`${name} ${role} contrast`)
 }
})


test('Midnight Feature is distinct from Halloween and has a readable export description',()=>{
 assert.notEqual(SHELF_THEMES.midnight_feature.bg,SHELF_THEMES.halloween.bg)
 assert.notEqual(SHELF_THEMES.midnight_feature.accent,SHELF_THEMES.halloween.accent)
 const alt=shelfImageAltText({picks:[],overview:false,category:'Movies',theme:'midnight_feature',format:'portrait',handle:'demo'})
 assert.match(alt,/Midnight Feature theme/);assert.match(alt,/No selections yet/)
})


test('saved headline is the shared identity for overview and category cards with safe fallbacks',()=>{
 const headline="it's finally spooky szn 🦇"
 for(const overview of [true,false])for(const format of ['landscape','portrait'])for(const layout of ['exhibition','reading','collector','mixtape']){
  const alt=shelfImageAltText({picks:[{title:'A selection'}],shelves:[{label:'Books',picks:[]}],overview,theme:'halloween',format,handle:'demo',category:'Books',headline,layout})
  assert.ok(alt.includes(headline));assert.doesNotMatch(alt,/top five|favorites/i)
  if(!overview)assert.match(alt,/Category: Books/)
 }
 for(const missing of [undefined,null,'','   ',42])assert.equal(shelfImageHeading(missing),'The things I keep.')
 assert.equal(shelfImageHeading('  🦇 strange nights  '),'🦇 strange nights')
})

test('remote artwork requests use anonymous CORS and failures resolve to a fallback', async () => {
 const {cover}=new Function(source+';return {cover}')()
 let request
 global.Image=class { set src(value){request=this;if(value)queueMicrotask(()=>this.onerror())} }
 assert.equal(await cover({cover:'https://artwork.example/blocked.jpg'}),null)
 assert.equal(request.crossOrigin,'anonymous')
 delete global.Image
})

test('all media artwork is contained with its original ratio',()=>{
 const {artwork}=new Function(source+';return {artwork}')()
 const draws=[]
 const ctx={fillRect(){},save(){},beginPath(){},rect(){},clip(){},restore(){},strokeRect(){},drawImage(...args){draws.push(args)}}
 for(const type of ['Book','Album','Movie','TvShow','Comic','VideoGame'])for(const [width,height] of [[200,300],[300,300],[400,200]]){
  artwork(ctx,{width,height},72,560,220,330,SHELF_THEMES.everyday,1,{type})
  const [,x,y,w,h]=draws.at(-1)
  assert.ok(x>=71.999&&y>=559.999&&x+w<=292.001&&y+h<=890.001)
  assert.ok(Math.abs(w/h-width/height)<1e-9)
 }
})


test('export links remain public and canonical when rendering from localhost',()=>{
 const {shelfPublicLink}=new Function(source+';return {shelfPublicLink}')()
 const expected='https://trove.schweg.xyz/@schwegler/shelf?category=overall'
 assert.equal(shelfPublicLink('schwegler',expected).href,expected)
 assert.equal(shelfPublicLink('schwegler',undefined,'/@schwegler/shelf?category=overall').href,expected)
 for(const invalid of ['http://localhost:3129/shelf','https://127.0.0.1/shelf','https://user:password@example.com/shelf']){
  const result=shelfPublicLink('schwegler',invalid)
  assert.equal(result.origin,'https://trove.schweg.xyz')
  assert.equal(result.pathname,'/@schwegler/shelf')
 }
})

test('Gallery, Feature and Mixtape have distinct five-pick compositions',()=>{
 const layouts=['exhibition','collector','mixtape'].map(name=>JSON.stringify(portraitShelfLayout(5,name)))
 assert.equal(new Set(layouts).size,3)
})
