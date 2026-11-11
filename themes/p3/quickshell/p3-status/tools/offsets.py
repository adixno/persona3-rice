#!/usr/bin/env python3
"""Write status-bg/offsets.json: how far the character moves from each frame to the next
(phase correlation on the character area). p3-status slides both frames by this during the
crossfade so the character stays registered. Re-run after reordering or adding frames.
usage: offsets.py ~/.local/share/persona-rice/media/p3/status-bg [preview.png]"""
import numpy as np, sys, os, json
from PIL import Image
d=sys.argv[1]
fs=sorted(f for f in os.listdir(d) if f.endswith('.png'))
ims=[np.asarray(Image.open(os.path.join(d,f)).convert('L')).astype(np.float32) for f in fs]
n=len(ims)
ys,xs=slice(180,1000),slice(950,1920)   # the character (hand, head, collar, body)
win=np.outer(np.hanning(ys.stop-ys.start),np.hanning(xs.stop-xs.start))
def shift(a,b):
    # where b's content sits relative to a's: b(x) ≈ a(x - s)
    A=np.fft.fft2(a*win); B=np.fft.fft2(b*win)
    R=B*np.conj(A); R/=np.abs(R)+1e-9
    r=np.fft.ifft2(R).real; y,x=np.unravel_index(r.argmax(),r.shape)
    if y>r.shape[0]//2: y-=r.shape[0]
    if x>r.shape[1]//2: x-=r.shape[1]
    return [int(x),int(y)]
off=[shift(ims[i][ys,xs],ims[(i+1)%n][ys,xs]) for i in range(n)]
print(off)
json.dump({"files":fs,"next":off},open(os.path.join(d,"offsets.json"),"w"))
# preview: plain vs compensated blend at t=0.5 for each step, cropped to the character
rgb=[Image.open(os.path.join(d,f)).convert('RGB') for f in fs]
rows=[]
for i in range(n):
    a,b=rgb[i],rgb[(i+1)%n]; dx,dy=off[i]
    plain=Image.blend(a,b,0.5)
    sa=Image.new('RGB',a.size); sa.paste(a,(round(dx*0.5),round(dy*0.5)))
    sb=Image.new('RGB',b.size); sb.paste(b,(round(-dx*0.5),round(-dy*0.5)))
    comp=Image.blend(sa,sb,0.5)
    box=(950,150,1750,850)
    row=Image.new('RGB',(1600,700)); row.paste(plain.crop(box),(0,0)); row.paste(comp.crop(box),(800,0))
    rows.append(row.resize((480,210)))
sheet=Image.new('RGB',(960,210*5))
for k,r in enumerate(rows): sheet.paste(r,((k%2)*480,(k//2)*210))
if len(sys.argv) > 2: sheet.save(sys.argv[2])   # optional preview: plain vs compensated blends
