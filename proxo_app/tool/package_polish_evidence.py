from pathlib import Path
import json, csv, gzip, hashlib, shutil, subprocess, re
root=Path(__file__).resolve().parents[2]
build=root/'proxo_app/build/polish-evidence'
out=root/'docs/auth-ux-redesign'
images=out/'images'
images.mkdir(exist_ok=True)
for old in images.glob('*.png'): old.unlink()
sections=['login','login-phone','login-phone-filled','signup','signup-filled','forgot','new-password','otp','otp-filled','splash','refresh','results-banner','results','results-empty','deposit','ads','create','profile','home','navigation','levels','tasks','vouchers','discounts','notifications']
records=[]
for path in sorted(build.glob('*.json')):
    if path.stem.endswith('-lifecycle'): continue
    data=json.loads(path.read_text())
    if data.get('section') not in sections: continue
    assert not data['exceptions'],path.name
    if data.get('position') == 'bottom':
        original=path.with_name(path.name.replace('-bottom.json','.json'))
        if original.exists() and path.stat().st_mtime < original.stat().st_mtime: continue
    normal=data['textScale']==1
    name=f"{data['section']}-{data['locale']}-{int(data['width'])}"+('' if normal else '-2x')+('-bottom' if data.get('position')=='bottom' else '')
    shot=path.with_suffix('.png')
    assert shot.exists(),path
    shutil.copyfile(shot,images/(name+'.png'))
    data['screenshot']='images/'+name+'.png'
    data['screenshot_sha256']=hashlib.sha256(shot.read_bytes()).hexdigest()
    data.pop('fixture',None)
    records.append(data)
main=[r for r in records if r.get('position')!='bottom']
assert len(main)==150,len(main)
assert len({(r['section'],r['locale'],r['width']) for r in main})==150
full={'renderer':'Flutter 3.47.2 headless widget tests with bundled fonts','units':'Flutter logical pixels; raster dimensions = viewport dimensions × DPR','fixture':'Production Flutter screens and shared widgets; fictional GET-only backend; no live authentication, OTP or payment sends','captures':records}
(out/'measurements.json.gz').write_bytes(gzip.compress(json.dumps(full,ensure_ascii=False).encode(),mtime=0))
with (out/'measurements.csv').open('w',newline='',encoding='utf-8-sig') as f:
    columns=['screenshot','section','locale','viewport_width_dp','viewport_height_dp','text_scale','dpr','widget','key','left_dp','top_dp','width_dp','height_dp','font_family','font_size','font_weight','line_height','text','exceeded_max_lines']
    writer=csv.DictWriter(f,fieldnames=columns,lineterminator="\n")
    writer.writeheader()
    for r in records:
        for row in r['layout']:
            x,y,w,h=row['bounds_dp']
            writer.writerow(dict(screenshot=r['screenshot'],section=r['section'],locale=r['locale'],viewport_width_dp=r['width'],viewport_height_dp=r['height'],text_scale=r['textScale'],dpr=r['dpr'],widget=row['widget'],key=row.get('key'),left_dp=round(x,3),top_dp=round(y,3),width_dp=round(w,3),height_dp=round(h,3),font_family=row.get('font_family'),font_size=row.get('font_size'),font_weight=(row['font_weight']+1)*100 if row.get('font_weight') is not None else None,line_height=row.get('line_height'),text=row.get('text'),exceeded_max_lines=row.get('exceeded_max_lines')))
summary=[]
for r in main:
    keys=['auth-app-bar','signup-submit','auth-intro-icon']
    selected=[]
    for row in r['layout']:
        if any(k in (row.get('key') or '') for k in keys) or row['widget'] in ['Image','TextField']:
            selected.append(row)
    summary.append({k:r[k] for k in ['section','locale','width','height','textScale','dpr','screenshot']}|{'components':selected})
(out/'component-bounds.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
labels={'login':'Email login','login-phone':'Phone login','signup':'Create account','signup-filled':'Create account (filled)','forgot':'Recovery','new-password':'New password','otp':'Verification'}
gallery=['# Auth screenshot matrix','', 'Actual production Flutter widgets. Each primary image has recorded RenderObject geometry in `measurements.csv` and `measurements.json.gz`. All images were captured with the bundled fonts.','']
for width,scale in [(393,1),(280,2)]:
    gallery += [f'## {width} dp — {scale}× text','', '| Screen | Sorani | Arabic | Badini |','|---|---|---|---|']
    for section in sections:
        links=[]
        for locale in ['ckb','ar','kmr']:
            r=next(x for x in main if x['section']==section and x['locale']==locale and x['width']==width)
            link=f"[View]({r['screenshot']})"
            bottom=next((x for x in records if x['section']==section and x['locale']==locale and x['width']==width and x.get('position')=='bottom'),None)
            if bottom: link+=f" · [Bottom]({bottom['screenshot']})"
            links.append(link)
        gallery.append('| '+labels.get(section, section)+' | '+' | '.join(links)+' |')
    gallery+=['']
(out/'screenshots.md').write_text('\n'.join(gallery).rstrip()+'\n')
for source,target in [('/tmp/proxo-polish-matrix.log','capture.log'),('/tmp/proxo-polish-behavior.log','behavior.log'),('/tmp/proxo-polish-analyze-final.log','analyze.log'),('/tmp/proxo-otp-center-capture.log','otp-centering.log'),('/tmp/proxo-full-suite-final.log','full-suite.log'),('/tmp/proxo-added-analyze.log','added-analyze.log')]:
    text=Path(source).read_text().replace(str(root)+'/','')
    (out/target).write_text('\n'.join(line.rstrip() for line in text.splitlines())+'\n')
files=subprocess.check_output(['git','diff','b86c93466fa993d93934fb72c5999761782fdbb1','--name-only','proxo_app/lib','proxo_app/test','proxo_app/assets','proxo_app/android','proxo_app/supabase','proxo_app/pubspec.yaml','proxo_app/l10n','proxo_app/integration_test','proxo_app/test_driver','scripts/run-polish-runtime.py','.github/workflows/proxolink-verify.yml','.github/workflows/polish-runtime.yml'],cwd=root,text=True).splitlines()
files+=subprocess.check_output(['git','ls-files','--others','--exclude-standard','proxo_app/assets/icons/auth','proxo_app/assets/images/auth','proxo_app/android/app/src/main/res','proxo_app/lib/screens/authenticated_gate.dart','proxo_app/test/proxo_polish_test.dart'],cwd=root,text=True).splitlines()
source_hashes={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in sorted(set(files)) if (root/name).is_file()}
analysis=Path('/tmp/proxo-polish-analyze-final.log').read_text()
focused=Path('/tmp/proxo-polish-behavior.log').read_text()
focused_passed=re.search(r'\+(\d+): All tests passed!',focused)
assert focused_passed,'Focused behavior suite must pass before packaging'
report={'base_branch':'feat/secure-operations-telemetry-20261016','base_commit':'b86c93466fa993d93934fb72c5999761782fdbb1','implementation_branch':'codex/auth-ux-redesign','flutter_version':'3.47.2','dart_version':'3.13.2','visual_cases_passed':150,'behavior_tests_passed':int(focused_passed[1]),'screenshots_including_scroll_bottoms':len(records),'captured_render_objects':sum(len(r['layout']) for r in records),'captured_exceptions':sum(len(r['exceptions']) for r in records),'paragraphs_exceeding_max_lines':sum(bool(row.get('exceeded_max_lines')) for r in records for row in r['layout']),'analyzer':{'errors':analysis.count('error •'),'warnings':analysis.count('warning •'),'infos':analysis.count('info •'),'notes':'Three pre-existing Auth warnings: unnecessary cast and visible-for-testing calls. Remaining lints are informational.'},'source_sha256':source_hashes,'screenshots':[{k:r[k] for k in ['section','locale','width','height','textScale','dpr','screenshot','screenshot_sha256']}|{'position':r.get('position','top')} for r in records]}
suite=Path('/tmp/proxo-full-suite-final.log').read_text()
passed=re.search(r'\+(\d+): All tests passed!',suite)
assert passed,'Full suite must pass before packaging'
help_images=out/'help-images'
help_images.mkdir(exist_ok=True)
help_records=[]
for path in sorted((root/'proxo_app/build/help-evidence').glob('*.json')):
    row=json.loads(path.read_text())
    assert not row['exceptions']
    shot=path.with_suffix('.png')
    shutil.copyfile(shot,help_images/shot.name)
    row['screenshot']='help-images/'+shot.name
    row['screenshot_sha256']=hashlib.sha256(shot.read_bytes()).hexdigest()
    help_records.append(row)
assert len(help_records)==24
(out/'help-measurements.json').write_text(json.dumps(help_records,ensure_ascii=False,indent=2)+'\n')
report.update(full_suite_tests_passed=int(passed[1]),context_help_visual_cases_passed=24,
              context_help_screenshots=24,android_profile_runtime='Run separately in Proxo Android polish runtime; see its CI artifact')
(out/'evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print({k:v for k,v in report.items() if k not in ['source_sha256','screenshots']})
