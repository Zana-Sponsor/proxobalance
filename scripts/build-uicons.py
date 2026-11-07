#!/usr/bin/env python3
"""Generate assets/js/index-svg-icons.js from Flaticon UIcons (Rounded).

Every interface icon on the customer site comes from one family:
"Uicons by Flaticon" (https://www.flaticon.com/uicons), Regular Rounded for
normal state and Solid Rounded for selected state. Glyph outlines are taken
from the official webfonts and emitted as inline SVG paths, so the browser
does not need to download a 300-400 KB icon font.

Usage:
  npm i --prefix /tmp/uicons @flaticon/flaticon-uicons@3.3.1
  curl -o /tmp/uicons/rr.woff2 https://cdn.jsdelivr.net/npm/@flaticon/flaticon-uicons@3.3.1/css/uicons-regular-rounded-J3WOUERV.woff2
  curl -o /tmp/uicons/sr.woff2 https://cdn.jsdelivr.net/npm/@flaticon/flaticon-uicons@3.3.1/css/uicons-solid-rounded-IYSBBSWN.woff2
  python3 scripts/build-uicons.py /tmp/uicons/node_modules/@flaticon/flaticon-uicons /tmp/uicons/rr.woff2 /tmp/uicons/sr.woff2
"""
import json
import re
import sys
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

# semantic key -> UIcons name (Regular Rounded)
REGULAR = {
    'arrow': 'angle-small-right', 'arrowBack': 'angle-small-left',
    'down': 'angle-small-down', 'up': 'angle-small-up',
    'arrowRight': 'arrow-small-right', 'arrowLeft': 'arrow-small-left',
    'send': 'paper-plane', 'transfer': 'exchange', 'vertical': 'sort-alt',
    'user': 'user', 'userPlus': 'user-add', 'userCheck': 'user-check', 'userId': 'id-badge',
    'check': 'check', 'checkCircle': 'check-circle', 'checkDouble': 'check-double',
    'close': 'cross-circle', 'closeSmall': 'cross-small', 'info': 'info',
    'warning': 'triangle-warning', 'shield': 'shield-check', 'shieldPlain': 'shield',
    'shieldWarning': 'shield-exclamation', 'verified': 'badge-check',
    'lock': 'lock', 'unlock': 'unlock', 'key': 'key',
    'bell': 'bell', 'bellOff': 'bell-slash', 'history': 'time-past', 'clock': 'clock-three',
    'receipt': 'receipt', 'wallet': 'wallet', 'card': 'credit-card',
    'upload': 'upload', 'download': 'download', 'image': 'picture', 'imageAdd': 'add-image',
    'camera': 'camera', 'file': 'file', 'document': 'document', 'idCard': 'id-card-clip-alt',
    'edit': 'pencil', 'save': 'disk', 'search': 'search', 'trash': 'trash',
    'graph': 'chart-line-up', 'graphDown': 'arrow-trend-down',
    'dollar': 'dollar', 'banknote': 'money-bill-wave', 'percent': 'badge-percent', 'gift': 'gift',
    'phone': 'phone-call', 'mail': 'envelope', 'chat': 'comment-dots', 'headset': 'headset',
    'power': 'sign-out-alt', 'bolt': 'bolt', 'refresh': 'refresh', 'copy': 'copy-alt',
    'calendar': 'calendar', 'plus': 'plus', 'minus': 'minus', 'equals': 'equals',
    'star': 'star', 'eye': 'eye', 'eyeOff': 'eye-crossed', 'sun': 'sun', 'moon': 'moon',
    'wifi': 'wifi', 'building': 'bank', 'sparkle': 'sparkles', 'tuning': 'settings-sliders',
    'settings': 'settings', 'home': 'home', 'bookmark': 'bookmark', 'list': 'list-check',
}
# semantic key -> UIcons name (Solid Rounded), used with the `icn-solid` class
SOLID = {
    'home': 'home', 'receipt': 'receipt', 'document': 'document', 'list': 'list-check',
    'user': 'user', 'star': 'star', 'bell': 'bell', 'gift': 'gift', 'wallet': 'wallet',
    'checkCircle': 'check-circle', 'close': 'cross-circle', 'warning': 'triangle-warning',
    'info': 'info', 'percent': 'badge-percent', 'shield': 'shield-check',
}
# legacy Solar class names used in markup/JS -> semantic key
ALIASES = {
    'alt-arrow-down-linear': 'down', 'alt-arrow-up-linear': 'up',
    'alt-arrow-left-linear': 'arrowBack', 'alt-arrow-right-linear': 'arrow',
    'arrow-left-linear': 'arrowLeft', 'arrow-right-linear': 'arrowRight',
    'banknote-2-linear': 'banknote', 'banknote-linear': 'banknote',
    'bell-linear': 'bell', 'bell-off-linear': 'bellOff', 'bill-list-linear': 'receipt',
    'bolt-linear': 'bolt', 'buildings-2-linear': 'building', 'calendar-linear': 'calendar',
    'card-linear': 'card', 'chat-round-dots-linear': 'chat', 'check-circle-linear': 'checkCircle',
    'check-read-linear': 'checkDouble', 'clock-circle-linear': 'clock', 'close-circle-linear': 'close',
    'copy-linear': 'copy', 'danger-triangle-linear': 'warning', 'diskette-linear': 'save',
    'dollar-linear': 'dollar', 'dollar-minimalistic-linear': 'dollar',
    'download-minimalistic-linear': 'download', 'download-linear': 'download',
    'gallery-add-linear': 'imageAdd', 'gallery-linear': 'image',
    'graph-down-linear': 'graphDown', 'graph-up-linear': 'graph',
    'headphones-round-linear': 'headset', 'history-2-linear': 'history', 'history-linear': 'history',
    'info-circle-linear': 'info', 'key-linear': 'key', 'letter-linear': 'mail', 'lock-linear': 'lock',
    'lock-unlocked-linear': 'unlock', 'magic-stick-3-linear': 'sparkle', 'magnifer-linear': 'search',
    'moon-linear': 'moon', 'pen-linear': 'edit', 'phone-linear': 'phone', 'plain-2-linear': 'send',
    'power-linear': 'power', 'refresh-linear': 'refresh', 'sale-linear': 'percent',
    'shield-check-linear': 'shield', 'shield-linear': 'shieldPlain', 'shield-warning-linear': 'shieldWarning',
    'star-linear': 'star', 'sun-linear': 'sun', 'transfer-horizontal-linear': 'transfer',
    'transfer-vertical-linear': 'vertical', 'tuning-2-linear': 'tuning', 'upload-linear': 'upload',
    'upload-minimalistic-linear': 'upload', 'user-check-rounded-linear': 'userCheck',
    'user-id-linear': 'userId', 'user-linear': 'user', 'user-rounded-linear': 'user',
    'user-plus-rounded-linear': 'userPlus', 'verified-check-linear': 'verified', 'wallet-linear': 'wallet',
    'wi-fi-router-linear': 'wifi', 'wi-fi-router-minimalistic-linear': 'wifi',
    'wi-fi-router-round-linear': 'wifi', 'eye-linear': 'eye', 'eye-closed-linear': 'eyeOff',
    'gift-linear': 'gift', 'home-linear': 'home', 'document-linear': 'document',
    'camera-linear': 'camera', 'trash-bin-minimalistic-linear': 'trash', 'settings-linear': 'settings',
    'bookmark-linear': 'bookmark', 'cross-linear': 'closeSmall', 'add-linear': 'plus',
}


def codepoints(css_path, prefix):
    css = Path(css_path).read_text()
    return {m.group(1): int(m.group(2), 16)
            for m in re.finditer(r'\.fi-%s-([a-z0-9-]+):before\{content:"\\([0-9a-f]+)"\}' % prefix, css)}


def paths(font_path, css_path, prefix, wanted):
    font = TTFont(font_path)
    upm = font['head'].unitsPerEm
    asc = font['hhea'].ascent
    cmap = font.getBestCmap()
    glyphs = font.getGlyphSet()
    cps = codepoints(css_path, prefix)
    scale = 24 / upm
    out = {}
    for key, name in wanted.items():
        if name not in cps:
            raise SystemExit(f'Missing UIcon fi-{prefix}-{name} for {key}')
        glyph = cmap[cps[name]]
        pen = SVGPathPen(glyphs, ntos=lambda v: ('%.2f' % v).rstrip('0').rstrip('.'))
        glyphs[glyph].draw(TransformPen(pen, (scale, 0, 0, -scale, 0, asc * scale)))
        out[key] = pen.getCommands()
    return out


def main():
    pkg, rr_font, sr_font = sys.argv[1:4]
    regular = paths(rr_font, Path(pkg, 'css/regular/rounded.css'), 'rr', REGULAR)
    solid = paths(sr_font, Path(pkg, 'css/solid/rounded.css'), 'sr', SOLID)
    for alias, key in ALIASES.items():
        assert key in regular, (alias, key)
    js = """/* Proxo Balance icon renderer - generated by scripts/build-uicons.py.
   One icon family for the whole site: Uicons by Flaticon (https://www.flaticon.com/uicons),
   Regular Rounded (normal) and Solid Rounded (`icn-solid`, selected states).
   Markup: <span class="icn icon--pb--KEY"></span> or legacy <span class="icn icon--solar--NAME"></span>. */
(function(){
'use strict';
const R=%s;
const SO=%s;
const A=%s;
function keyOf(node){
 for(const c of node.classList){
  if(c.indexOf('icon--pb--')===0)return c.slice(10);
  if(c.indexOf('icon--solar--')===0)return A[c.slice(13)]||'info';
 }
 return null;
}
function make(key,solid,extra){
 const d=(solid&&SO[key])||R[key]||R.info;
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 svg.setAttribute('viewBox','0 0 24 24');svg.setAttribute('fill','currentColor');
 svg.setAttribute('aria-hidden','true');svg.setAttribute('focusable','false');
 svg.classList.add('icn','pb-svg-icon','pb-svg-'+key);
 if(solid&&SO[key])svg.classList.add('pb-svg-solid');
 (extra||[]).forEach(c=>svg.classList.add(c));
 svg.innerHTML='<path d="'+d+'"/>';
 return svg;
}
function convert(node){
 const key=keyOf(node);if(!key)return;
 const keep=[...node.classList].filter(c=>c!=='icn'&&c.indexOf('icon--')!==0);
 const svg=make(key,node.classList.contains('icn-solid'),keep);
 if(node.id)svg.id=node.id;
 node.replaceWith(svg);
}
const SELECTOR='[class*="icon--solar--"],[class*="icon--pb--"]';
function scan(root=document){
 if(root.matches?.(SELECTOR))convert(root);
 root.querySelectorAll?.(SELECTOR).forEach(convert);
}
function html(key,cls){
 return '<span class="icn icon--pb--'+key+(cls?' '+cls:'')+'" aria-hidden="true"></span>';
}
scan();
new MutationObserver(records=>{for(const r of records)for(const n of r.addedNodes)if(n.nodeType===1)scan(n);})
 .observe(document.documentElement,{childList:true,subtree:true});
window.PBSvgIcons={scan,html,has:k=>!!R[k]};
})();
""" % (json.dumps(regular, separators=(',', ':')), json.dumps(solid, separators=(',', ':')),
       json.dumps(ALIASES, separators=(',', ':')))
    target = Path(__file__).resolve().parents[1] / 'assets/js/index-svg-icons.js'
    target.write_text(js)
    print(f'Wrote {target} ({len(js)//1024} KB, {len(regular)} regular, {len(solid)} solid, {len(ALIASES)} aliases)')


if __name__ == '__main__':
    main()
