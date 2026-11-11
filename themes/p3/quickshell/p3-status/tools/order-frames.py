#!/usr/bin/env python3
"""Order p3-status slideshow frames so neighbours differ the least (character bob, water drift,
ring rotation), as a loop. Brute force, fine up to ~11 frames.
usage: order-frames.py ~/.local/share/persona-rice/media/p3/status-bg [--apply]
needs numpy + pillow (e.g. a venv)."""
import numpy as np, sys, os, itertools
from PIL import Image
d=sys.argv[1]
fs=sorted(f for f in os.listdir(d) if f.endswith('.png'))
ims=[np.asarray(Image.open(os.path.join(d,f)).convert('L')).astype(np.float32) for f in fs]
n=len(ims)
def shift(a,b):
    A=np.fft.fft2(a); B=np.fft.fft2(b)
    R=A*np.conj(B); R/=np.abs(R)+1e-9
    r=np.fft.ifft2(R).real; y,x=np.unravel_index(r.argmax(),r.shape)
    if y>r.shape[0]//2: y-=r.shape[0]
    if x>r.shape[1]//2: x-=r.shape[1]
    return np.hypot(x,y)
regions={'water':(slice(0,300),slice(0,600),0.6),'bg':(slice(600,1000),slice(0,500),0.6),
         'body':(slice(700,1000),slice(1350,1800),1.0),'hand':(slice(220,620),slice(1000,1500),1.5),
         'ring':(slice(0,700),slice(590,950),1.0)}
D=np.zeros((n,n))
for i in range(n):
    for j in range(i+1,n):
        m=0
        for ys,xs,w in regions.values():
            m+=w*shift(ims[i][ys,xs],ims[j][ys,xs])
        # ring text rotation shows up as pixel change inside the ring band
        m+=0.5*np.abs(ims[i][0:700,590:950]-ims[j][0:700,590:950]).mean()
        D[i,j]=D[j,i]=m
def cost(p): return sum(D[p[k],p[(k+1)%n]] for k in range(n))
cur=list(range(n))
best=min(([0]+list(p) for p in itertools.permutations(range(1,n))), key=cost)
print("current order cost", round(cost(cur),1), "steps", [round(D[cur[k],cur[(k+1)%n]]) for k in range(n)])
print("best order", [fs[i] for i in best])
print("best cost", round(cost(best),1), "steps", [round(D[best[k],best[(k+1)%n]]) for k in range(n)])
if "--apply" in sys.argv:
    # rename into the smooth order (01.png, 02.png, ...) via temp names
    ext = lambda f: os.path.splitext(f)[1]
    tmp = [f"tmp-{k+1:02d}{ext(fs[i])}" for k, i in enumerate(best)]
    for k, i in enumerate(best): os.rename(os.path.join(d, fs[i]), os.path.join(d, tmp[k]))
    for t in tmp: os.rename(os.path.join(d, t), os.path.join(d, t[4:]))
    print("renamed; now run offsets.py")
