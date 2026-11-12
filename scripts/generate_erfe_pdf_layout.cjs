/* Font layout metadata only; every text unit comes from the unique linguistic JSON. */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const fontkit=require(path.join(root,'backend/static/webapp/js/vendor/fontkit.umd.min.js'));
const source=JSON.parse(fs.readFileSync(path.join(root,'shared/linguistics/beriya_erfe_transliteration_mapping.json')));
const result={};
for(const weight of ['Regular','Bold']) {
  const bytes=fs.readFileSync(path.join(root,`mobile/assets/fonts/Kedebideri-${weight}.ttf`));
  const font=fontkit.create(bytes), units={};
  for(const row of source.diacritic_letters) {
    const layout=font.layout(row.erfe);
    if(layout.glyphs.some(g=>g.id===0)) throw Error('Missing font glyph');
    const [a,b] = layout.positions;
    if(layout.glyphs.length!==2 || a.xOffset!==0 || a.yOffset!==0 || b.yOffset!==0 || b.xAdvance!==0)
      throw Error('Font layout changed: recheck two-glyph PDF anchoring');
    units[row.erfe]=layout.glyphs.map((g,i)=>({text:String.fromCodePoint(...g.codePoints),
      xAdvance:layout.positions[i].xAdvance,xOffset:layout.positions[i].xOffset,yOffset:layout.positions[i].yOffset}));
  }
  result[weight.toLowerCase()]={sha256:crypto.createHash('sha256').update(bytes).digest('hex'),
    unitsPerEm:font.unitsPerEm,ascent:font.ascent,descent:font.descent,units};
}
const target=path.join(root,'mobile/lib/features/editor/services/erfe_pdf_layout_data.dart');
const text="// Generated from Kedebideri anchors, not a linguistic mapping. Do not edit.\nimport 'dart:convert';\nfinal Map<String, dynamic> erfePdfLayoutData = jsonDecode(r'''"+JSON.stringify(result)+"''') as Map<String, dynamic>;\n";
if(process.argv.includes('--check')) {
  if(fs.readFileSync(target,'utf8').replace(/\r\n/g,'\n')!==text) throw Error('Outdated PDF font layout data');
} else fs.writeFileSync(target,text);
