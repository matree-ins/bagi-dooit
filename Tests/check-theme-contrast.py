import json
from pathlib import Path
r=Path(__file__).resolve().parents[1]/'JustDooit/Resources/Assets.xcassets'
def rgb(name,mode):
 entries=json.loads((r/(name+'.colorset')/'Contents.json').read_text())['colors']
 for v in entries:
  dark=any(x.get('value')=='dark' for x in v.get('appearances',[]))
  if dark == (mode=='dark'):
   return tuple(float(v['color']['components'][c]) for c in ['red','green','blue'])
 raise AssertionError(f'Missing {mode}: {name}')
def luminance(c):
 c=[v/12.92 if v<=0.04045 else ((v+0.055)/1.055)**2.4 for v in c]
 return sum(a*b for a,b in zip(c,[0.2126,0.7152,0.0722]))
def contrast(a,b):
 x,y=sorted([luminance(a),luminance(b)])
 return (y+0.05)/(x+0.05)
count=0
for mode in ['light','dark']:
 for fg in ['BagiInk','BagiMuted','BagiPrimary','BagiSuccess','BagiWarning','BagiDanger']:
  ratio=contrast(rgb(fg,mode),rgb('BagiSurface',mode))
  assert ratio>=4.5,(mode,fg,ratio)
  print(f'PASS contrast {mode} {fg}: {ratio:.2f}:1');count+=1
 ratio=contrast((1,1,1),rgb('BagiAction',mode));assert ratio>=4.5
 print(f'PASS contrast {mode} white/action: {ratio:.2f}:1');count+=1
 for name in ['BagiBackground','BagiSurface','BagiSoft','BagiInk','BagiMuted']:
  assert rgb(name,'light') != rgb(name,'dark')
print(f'{count} text contrast checks passed; semantic surfaces have both appearances.')
