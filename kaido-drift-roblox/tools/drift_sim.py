# Offline tuning harness for src/client/Drive.lua (planar port, no Roblox needed).
# Usage: python3 tools/drift_sim.py [ps13|ae8|jza]
# Planar port of Drive.lua's tyre model to sanity-check drifting behaviour offline.
import math, sys
G=52.0; ACC=G/9.81; MPS=0.28; KMH=0.28*3.6; R_M=0.31
car=dict(torque=255,peak=4000,red=7200,mass=1240,front=0.53,gears=[3.32,1.9,1.31,1,0.76],final=4.08,mu=1.03,lock=48,CdA=0.68,turbo=True,len=4.52,wid=1.69,wb=2.47)
if len(sys.argv)>1 and sys.argv[1]=="jza":
    car.update(torque=620,peak=4500,red=7400,mass=1490,front=0.54,gears=[3.83,2.36,1.69,1.31,1,0.79],final=3.5,mu=1.16,lock=55,CdA=0.64,len=4.52,wid=1.81,wb=2.55)
if len(sys.argv)>1 and sys.argv[1]=="ae8":
    car.update(torque=155,peak=6000,red=8200,mass=925,front=0.52,gears=[3.59,2.02,1.38,1,0.86],final=4.78,mu=1.04,lock=52,CdA=0.64,turbo=False,len=4.2,wid=1.63,wb=2.4)
S=1/0.28
L=car['len']*S; W=car['wid']*S; WB=car['wb']*S
M=car['mass']; I=M*(W*W+L*L)/12
wx=W/2-0.22*S/2-0.05
wheels=[(-wx,-WB/2,True),(wx,-WB/2,True),(-wx,WB/2,False),(wx,WB/2,False)]
LAT=0.6
KB=0.7; KG=0.65; AS=1.5; SPIN=10.0; FLOOR=0.55; EASE=30.0; RAWA=0.7
import os
KB=float(os.environ.get('KB',KB)); KG=float(os.environ.get('KG',KG)); AS=float(os.environ.get('AS',AS)); SPIN=float(os.environ.get('SPIN',SPIN)); FLOOR=float(os.environ.get('FLOOR',FLOOR)); EASE=float(os.environ.get('EASE',EASE)); RAWA=float(os.environ.get('RAWA',RAWA))
def torqueAt(r):
    if r<=car['peak']: return car['torque']*(0.55+0.45*min(max(r/car['peak'],0),1))
    u=min(max((r-car['peak'])/max(car['red']-car['peak'],1),0),1); return car['torque']*(1-0.38*u*u)
def rpmFor(vF,g): return abs(vF)*MPS/R_M/(2*math.pi)*60*car['gears'][g-1]*car['final']
def sign(x): return (x>0)-(x<0)
class St: pass
def run(script, T, easy=True, log_every=0.5, label=""):
    s=St(); s.x=s.z=0; s.h=0.0  # heading: fwd = (sin h? ) use fwd=(-sin h, -cos h) world (x,z); h=0 => -Z
    s.vx=0; s.vz=0; s.w=0  # w = yaw rate about +Y (positive = left turn)
    gear=1; rpm=900; shift=0; steer=0; kick=0; kcd=0; rev=False
    t=0; dt=1/60; out=[]; maxslip=0; spins=0
    nexlog=0
    while t<T:
        thr,brk,st,hb=script(t,s)
        fwd=(-math.sin(s.h),-math.cos(s.h)); rgt=(math.cos(s.h),-math.sin(s.h))
        # check: h=0 fwd=(0,-1) rgt=(1,0) ok; left turn positive w increases h -> fwd rotates toward -X: h=+90deg fwd=(-1,0) ok
        vF=s.vx*fwd[0]+s.vz*fwd[1]; vL=s.vx*rgt[0]+s.vz*rgt[1]
        planar=math.hypot(vF,vL); kmh=planar*KMH
        beta=math.atan2(vL,vF) if vF>1 and planar>4 else 0
        slip=math.degrees(beta); a=abs(slip)
        lock=math.radians(car['lock']); sliding=a>8 and kmh>15
        sf=1 if sliding else 1-0.7*min(max(kmh/150,0),1)
        assist=0.9 if easy else RAWA
        tgt=max(-lock,min(lock,st*lock*sf+beta*assist))
        rate=7 if sign(tgt-steer)!=sign(steer) else 4.5
        steer+=max(-rate*dt,min(rate*dt,tgt-steer))
        throttle=thr
        kcd=max(0,kcd-dt); kick=max(0,kick-dt)
        if easy and thr>0.5 and abs(st)>0.6 and kmh>30 and a<12 and kcd<=0:
            s.w+=-sign(st)*(KB+0.3*min(max((kmh-30)/80,0),1)); kick=0.35; kcd=1.0
        if easy and a>EASE: throttle*=min(max(1-(a-EASE)/30,0.4),1)
        if hb: throttle=0
        spinLimit=55 if easy else 75
        if a>spinLimit: s.w-=s.w*min(1,dt*4*(a-spinLimit)/20)
        elif easy and a>20 and sign(s.w)==-sign(beta): s.w-=s.w*min(1,dt*1.2)
        nG=len(car['gears']); shift=max(0,shift-dt)
        if brk>0.1 and throttle<0.1 and vF<1.5: rev=True
        elif throttle>0.1 or vF>3: rev=False
        wr=rpmFor(vF,gear)
        if not rev and shift<=0:
            up=car['red']*(0.985 if sliding else 0.93)
            if wr>up and gear<nG: gear+=1; shift=0.2
            elif gear>1:
                if rpmFor(vF,gear-1)<car['red']*0.78 and wr<car['peak']*0.7: gear-=1; shift=0.15
        wr=rpmFor(vF,gear)
        rt=max(900,wr)
        if throttle>0.05 and (sliding or kmh<12): rt=max(rt,900+(car['red']*0.92-900)*throttle*(0.85 if sliding else 0.55))
        rpm+=(rt-rpm)*min(1,dt*10); rpm=min(max(rpm,810),car['red'])
        driveN=0
        if rev:
            if abs(vF)*KMH<25: driveN=-brk*car['torque']*3.4*car['final']*0.85/R_M*0.6
        elif shift<=0 and throttle>0:
            if wr<car['red']*0.995:
                eff=max(wr,min(rpm,car['peak']))
                driveN=torqueAt(eff)*car['gears'][gear-1]*car['final']*0.85/R_M*throttle
                if car['turbo']: driveN*=0.85+0.15*min(max((rpm-2500)/2000,0),1)
        da=driveN/car['mass']; dforce=da*ACC*M
        vFm=vF*MPS
        dragA=0.5*1.2*car['CdA']*vFm*abs(vFm)/car['mass']+0.12*sign(vF)*min(1,abs(vF))
        imp=[-fwd[0]*dragA*ACC*M*dt,-fwd[1]*dragA*ACC*M*dt]; torque=0
        bf=0 if rev else brk*11*ACC*M
        if sliding and throttle>0.1 and vF>0 and planar>0:
            aa=throttle*min(1,a/25)*(AS if easy else AS*0.6)*ACC*M*dt
            imp[0]+=s.vx/planar*aa; imp[1]+=s.vz/planar*aa
        mu=car['mu']; rg=1
        if hb: rg*=0.42
        if kick>0: rg*=KG
        if sliding and throttle>0.3: rg*=0.9
        if not sliding and not hb and kick<=0: rg*=1.08
        ex=da/(mu*9.81); rg*=1-throttle*min(max(ex*0.35,0),0.3)
        fg=1+(car['front']-0.5)*0.6
        Fs=M*G/4; q=M/4
        parked=throttle==0 and brk==0 and not hb and planar<1.2
        for (x,zz,front) in wheels:
            # contact point offset in world
            ox=x*rgt[0]-zz*fwd[0]; oz=x*rgt[1]-zz*fwd[1]   # local z positive = rear => -fwd
            pvx=s.vx - s.w*(-oz)*-1 if False else s.vx
            # point velocity: v + w x r ; w about +Y: w x r = (w*r_z, 0, -w*r_x)
            pvx=s.vx+s.w*oz; pvz=s.vz-s.w*ox
            if front:
                ang=-steer  # rotate fwd about +Y by -steer
                c,sn=math.cos(ang),math.sin(ang)
                # rotation about +Y: x' = x c + z s ; z' = -x s + z c
                wf=(fwd[0]*c+fwd[1]*sn, -fwd[0]*sn+fwd[1]*c)
            else: wf=fwd
            wrv=(-wf[1],wf[0])  # wf x up : for wf=(0,-1) -> (1,0)
            vxw=pvx*wf[0]+pvz*wf[1]; vyw=pvx*wrv[0]+pvz*wrv[1]
            maxF=mu*Fs*(fg if front else rg)
            fx=0; fy=-vyw*q/dt*LAT
            if parked: fx=-vxw*q/dt*0.5
            else: fx-=sign(vxw)*min(bf*(0.3 if front else 0.2),abs(vxw)*q/dt)
            if not front:
                fx+=dforce/2
                if hb and abs(vxw)>0.5: fx-=sign(vxw)*maxF*0.8
                fx=max(-maxF*0.95,min(maxF*0.95,fx))
                cap=max(math.sqrt(max(maxF*maxF-fx*fx,0)), maxF*(FLOOR if not hb else 0.3))
                fy=max(-cap,min(cap,fy))
            else:
                tot=math.hypot(fx,fy)
                if tot>maxF: fx*=maxF/tot; fy*=maxF/tot
            Fx=(wf[0]*fx+wrv[0]*fy)*dt; Fz=(wf[1]*fx+wrv[1]*fy)*dt
            imp[0]+=Fx; imp[1]+=Fz
            # torque about +Y: r x F (y comp) = r_z*F_x - r_x*F_z
            torque+=oz*Fx-ox*Fz
        s.vx+=imp[0]/M; s.vz+=imp[1]/M; s.w+=torque/I
        s.x+=s.vx*dt; s.z+=s.vz*dt; s.h+=s.w*dt
        t+=dt
        maxslip=max(maxslip,a) if kmh>20 else maxslip
        if t>=nexlog:
            out.append(f"{label} t={t:5.2f} kmh={kmh:6.1f} gear={gear} rpm={rpm:5.0f} slip={slip:6.1f} w={s.w:5.2f} steer={math.degrees(steer):6.1f}")
            nexlog+=log_every
    return out,maxslip
import itertools
def accel(t,s): return (1,0,0,False)
o,_=run(accel,22,label="accel",log_every=2); print("\n".join(o))
# corner at 70 km/h, gentle steer, no throttle beyond cruise
def grip(t,s):
    kmh=math.hypot(s.vx,s.vz)*KMH
    thr= 1 if kmh<70 and t<6 else (0.35 if t>=6 else 0)
    return (thr,0,0.5 if t>6 else 0,False)
o,m=run(grip,12,label="grip",log_every=1); print("\n".join(o[-5:]),"maxslip",round(m,1))
# easy drift: get to 70, then full gas + full left steer for 1s, then release steer to hold
def drift(t,s):
    kmh=math.hypot(s.vx,s.vz)*KMH
    if t<6: return (1 if kmh<75 else 0.3,0,0,False)
    if t<7: return (1,0,-1,False)
    return (1,0,-0.3,False)
for easy in (True,False):
    o,m=run(drift,12,easy=easy,label=("easy" if easy else "raw "),log_every=0.5); print("\n".join(o[11:]),"maxslip",round(m,1))
# handbrake entry
def hbk(t,s):
    kmh=math.hypot(s.vx,s.vz)*KMH
    if t<6: return (1 if kmh<70 else 0.3,0,0,False)
    if t<6.5: return (0,0,0.8,True)
    return (0.8,0,0.2,False)
o,m=run(hbk,11,easy=True,label="hb",log_every=0.5); print("\n".join(o[11:]),"maxslip",round(m,1))

print("==== scenarios")
def summary(name, fn, easy=True, T=14):
    o,m=run(fn,T,easy=easy,label=name,log_every=0.1)
    import re
    vals=[]
    for l in o:
        d=dict(re.findall(r'(\w+)=\s*(-?[\d.]+)',l)); vals.append((float(d['t']),float(d['kmh']),float(d['slip'])))
    dr=[v for v in vals if v[0]>6.3]
    held=sum(1 for v in dr if abs(v[2])>10 and v[1]>25)*0.1
    spun=sum(1 for v in dr if abs(v[2])>80)*0.1
    avg=sum(abs(v[2]) for v in dr if abs(v[2])>10)/max(1,sum(1 for v in dr if abs(v[2])>10))
    print(f"{name:14s} easy={easy!s:5s} drift_s={held:4.1f} avg_angle={avg:5.1f} spun_s={spun:3.1f} end_kmh={dr[-1][1]:5.1f} min_kmh={min(v[1] for v in dr):5.1f}")
def flick(t,s):
    kmh=math.hypot(s.vx,s.vz)*KMH
    if t<6: return (1 if kmh<75 else 0.3,0,0,False)
    if t<6.35: return (1,0,-1,False)
    return (0.8,0,0,False)
def hbflick(t,s):
    kmh=math.hypot(s.vx,s.vz)*KMH
    if t<6: return (1 if kmh<75 else 0.3,0,0,False)
    if t<6.4: return (0.5,0,-0.9,True)
    return (0.8,0,0,False)
def bot(target):
    def f(t,s):
        kmh=math.hypot(s.vx,s.vz)*KMH
        if t<6: return (1 if kmh<75 else 0.3,0,0,False)
        if t<6.35: return (1,0,-1,False)
        fwd=(-math.sin(s.h),-math.cos(s.h)); rgt=(math.cos(s.h),-math.sin(s.h))
        vF=s.vx*fwd[0]+s.vz*fwd[1]; vL=s.vx*rgt[0]+s.vz*rgt[1]
        slip=math.degrees(math.atan2(vL,max(vF,0.1)))
        # left drift => slip positive. too much angle -> steer right (countersteer more) and lift
        err=slip-target
        st=max(-1,min(1,-0.6+0.04*err))
        thr=max(0.2,min(1,0.8-0.03*err))
        return (thr,0,st,False)
    return f
def exitf(t,s):
    kmh=math.hypot(s.vx,s.vz)*KMH
    if t<6: return (1 if kmh<75 else 0.3,0,0,False)
    if t<6.35: return (1,0,-1,False)
    if t<8.5: return (0.8,0,0,False)
    return (0.0,0,0,False)
def exit_check(easy):
    o,m=run(exitf,13,easy=easy,log_every=0.5)
    import re
    tail=[dict(re.findall(r'(\w+)=\s*(-?[\d.]+)',l)) for l in o if 9.5<=float(re.findall(r't=\s*([\d.]+)',l)[0])]
    print("  lift-off exit:", ", ".join(f"t{float(d['t']):.1f} {float(d['slip']):.0f}deg {float(d['kmh']):.0f}kmh" for d in tail[::2]))
for easy in (True,False):
    exit_check(easy)
    summary("flick+release",flick,easy)
    summary("handbrake",hbflick,easy)
    summary("bot30",bot(30),easy)
