"""Read-only inventory. No downloaded icons or modified asset bytes."""
from pathlib import Path
import hashlib,json,re
from collections import Counter
from PIL import Image
root=Path(__file__).resolve().parents[2]
refs=[]
for p in sorted((root/'proxo_app/lib').rglob('*.dart')):
    block=False
    for number,line in enumerate(p.read_text().splitlines(),1):
        if line.strip().startswith('/*'): block=True
        if block:
            if '*/' in line: block=False
            continue
        if line.lstrip().startswith('//'): continue
        for m in re.finditer(r'\b(Icons|SolarIconsOutline|SolarIcons|FontAwesomeIcons)\.([A-Za-z_0-9]+)',line):
            refs.append({'path':str(p.relative_to(root)),'line':number,'family':m[1],'glyph':m[2]})
assets=[]
for p in sorted((root/'proxo_app/assets/icons').rglob('*')):
    if p.suffix not in ['.png','.svg']: continue
    info={'path':str(p.relative_to(root)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
    if p.suffix=='.png':
        image=Image.open(p).convert('RGBA');a=image.getchannel('A')
        info.update(size_px=list(image.size),alpha_bounds_px=a.getbbox(),alpha_coverage=sum(a.getdata())/(255*image.width*image.height))
    else:
        info['viewBox']=re.search(r'viewBox="([^"]+)"',p.read_text()).group(1) if 'viewBox=' in p.read_text() else None
    assets.append(info)
result={'method':'Non-comment lexical glyph references, not runtime usage; raster alpha bounds in source pixels. Package-internal SVGs are not local assets.','families':dict(Counter(r['family'] for r in refs)),'references':refs,'assets':assets}
(root/'docs/icon-inventory-2026-10-14.json').write_text(json.dumps(result,indent=2))
print({'references':len(refs),'dart_files':len(set(x['path'] for x in refs)),'local_assets':len(assets),'families':result['families']})
