import test from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import {compareNativePixels,validateViewport} from '../scripts/proxolink-pixel-comparison.mjs';

test('native comparison crops system/Flutter chrome and detects a single changed pixel',async()=>{
  const viewport=validateViewport({left:2,top:3,width:320,height:100,css_height:100,private_token:'discard'},320);
  assert.equal(viewport.private_token,undefined);
  const reference=await sharp({create:{width:320,height:100,channels:3,background:'#ffffff'}}).png().toBuffer();
  const screen=await sharp({create:{width:324,height:106,channels:3,background:'#000000'}})
    .composite([{input:reference,left:2,top:3}]).png().toBuffer();
  const equal=await compareNativePixels(screen,reference,viewport);
  assert.equal(equal.metrics.exact_pixels_equal,true);assert.equal(equal.metrics.changed_pixels,0);
  const changed=await sharp(reference).composite([{input:await sharp({create:{width:1,height:1,channels:3,background:'#000000'}}).png().toBuffer(),left:10,top:10}]).png().toBuffer();
  const difference=await compareNativePixels(screen,changed,viewport);
  assert.equal(difference.metrics.exact_pixels_equal,false);
  assert.equal(difference.metrics.changed_pixels,1);assert.equal(difference.metrics.max_channel_error,255);
});

test('invalid viewport and mismatched reference cannot produce a pixel parity result',async()=>{
  const crop={left:0,top:0,width:320,height:100,css_height:100};
  for(const change of [{left:-1},{width:393},{height:99},{css_height:99},{left:0.5}])
    assert.throws(()=>validateViewport({...crop,...change},320));
  const frame=await sharp({create:{width:320,height:100,channels:3,background:'#fff'}}).png().toBuffer();
  await assert.rejects(compareNativePixels(frame,frame,{...crop,left:1}),/native_crop_outside_screen/);
  const other=await sharp({create:{width:320,height:101,channels:3,background:'#fff'}}).png().toBuffer();
  await assert.rejects(compareNativePixels(frame,other,crop),/reference_viewport_mismatch/);
});
