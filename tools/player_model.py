"""Build the player-only clothed mesh on the existing interaction-compatible skeleton."""
import bpy, math
from mathutils import Vector

def build(rig):
    mats={}
    for name,color in {'linen':(.30,.39,.36,1),'vest':(.105,.18,.18,1),'leather':(.15,.085,.045,1),'edge':(.32,.22,.12,1),'pants':(.12,.15,.16,1),'skin':(.56,.35,.22,1),'hair':(.085,.047,.027,1),'eye':(.025,.025,.022,1),'metal':(.52,.40,.20,1)}.items():
        color=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in color[:3])+(1,)
        m=bpy.data.materials.new('Player_'+name);m.diffuse_color=color;m.use_nodes=True
        bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=color;bs.inputs['Roughness'].default_value=.85
        mats[name]=m
    parts=[]
    def mesh(name,verts,faces,mat,weights):
        data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
        ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob);ob.data.materials.append(mats[mat])
        for i,ws in enumerate(weights):
            for bone,w in ws.items():
                g=ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone);g.add([i],w,'REPLACE')
        mod=ob.modifiers.new('Skin','ARMATURE');mod.object=rig
        ob.parent=rig
        for p in data.polygons:p.use_smooth=True
        parts.append(ob);return ob
    def rings(name,rows,mat,bone,n=12):
        vs=[];weights=[]
        for x,y,z,rx,ry,ws in rows:
            for i in range(n):
                a=math.tau*i/n;vs.append((x+rx*math.cos(a),y+ry*math.sin(a),z));weights.append(ws or {bone:1})
        fs=[tuple(range(n-1,-1,-1))]
        for j in range(len(rows)-1):
            for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
        fs.append(tuple((len(rows)-1)*n+i for i in range(n)))
        return mesh(name,vs,fs,mat,weights)
    def bodyrows(spec,bone):return [(0,y,z,x,r,None) for z,x,r,y in spec]
    rings('TailoredTunic',bodyrows([(.84,.205,.14,0),(.96,.20,.145,0),(1.07,.17,.13,0),(1.26,.225,.145,0),(1.43,.24,.125,0),(1.49,.12,.09,0)],'Chest'),'linen','Chest')
    rings('FittedVest',bodyrows([(1.05,.178,.139,0),(1.16,.20,.15,0),(1.34,.236,.153,0),(1.44,.23,.135,0),(1.47,.105,.10,0)],'Chest'),'vest','Chest')
    rings('WaistBelt',bodyrows([(1.035,.183,.148,0),(1.095,.184,.149,0)],'Chest'),'leather','Chest')
    rings('Neck',bodyrows([(1.46,.069,.062,0),(1.59,.069,.064,0)],'Head'),'skin','Head')
    rings('Face',bodyrows([(1.56,.055,.068,-.008),(1.59,.087,.086,-.015),(1.68,.104,.098,-.005),(1.76,.102,.095,0),(1.82,.071,.072,0),(1.84,.025,.028,0)],'Head'),'skin','Head',16)
    rings('SweptHair',bodyrows([(1.735,.106,.083,.025),(1.79,.112,.10,.01),(1.845,.077,.074,.005),(1.862,.025,.025,0)],'Head'),'hair','Head',16)
    def box(name,loc,size,mat,bone):
        x,y,z=loc;a,b,c=[v/2 for v in size]
        verts=[(x+dx*a,y+dy*b,z+dz*c) for dx,dy,dz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        return mesh(name,verts,[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)],mat,[{bone:1}]*8)
    mesh('SplitCollar',[(-.09,-.094,1.48),(-.018,-.157,1.39),(-.135,-.143,1.44),(.09,-.094,1.48),(.135,-.143,1.44),(.018,-.157,1.39)],[(0,1,2),(3,4,5)],'linen',[{'Chest':1}]*6)
    box('Nose',(0,-.108,1.68),(.032,.036,.063),'skin','Head')
    box('Buckle',(0,-.155,1.067),(.058,.018,.049),'metal','Chest')
    for x in [-.044,.044]:
        box('Eye',(x,-.098,1.725),(.023,.012,.011),'eye','Head')
        box('Brow',(x,-.099,1.743),(.032,.014,.01),'hair','Head')
    for z in [1.18,1.26,1.34]:box('VestFastening',(0,-.153,z),(.017,.014,.021),'metal','Chest')
    for side,sign in [('L',-1),('R',1)]:
        x=.135*sign
        rings('Trouser'+side,[(x,0,.16,.071,.071,{'Shin.'+side:1}),(x,0,.48,.075,.073,{'Shin.'+side:1}),(x,-.01,.55,.084,.082,{'Thigh.'+side:.65,'Shin.'+side:.35}),(x,0,.74,.10,.105,None),(x,0,.91,.112,.12,None)],'pants','Thigh.'+side)
        rings('Boot'+side,[(x,-.055,.035,.085,.155,{'Foot.'+side:1}),(x,-.06,.10,.087,.16,{'Foot.'+side:1}),(x,-.025,.18,.073,.091,{'Foot.'+side:.3,'Shin.'+side:.7}),(x,0,.36,.077,.079,None)],'leather','Shin.'+side)
        rings('BootCuff'+side,[(x,0,.335,.083,.085,None),(x,0,.375,.083,.085,None)],'edge','Shin.'+side)
        rings('Sleeve'+side,[(sign*.36,-.02,.99,.057,.06,{'Forearm.'+side:1}),(sign*.347,-.01,1.13,.062,.065,{'Forearm.'+side:1}),(sign*.335,0,1.20,.065,.07,{'Forearm.'+side:.5,'UpperArm.'+side:.5}),(sign*.285,0,1.35,.079,.08,None),(sign*.245,0,1.435,.084,.084,None)],'linen','UpperArm.'+side)
        rings('Cuff'+side,[(sign*.362,-.02,.98,.061,.064,None),(sign*.352,-.016,1.04,.065,.067,None)],'leather','Forearm.'+side)
        rings('Hand'+side,[(sign*.38,-.025,.837,.04,.043,None),(sign*.38,-.033,.88,.049,.045,None),(sign*.375,-.025,.96,.044,.042,None)],'skin','Hand.'+side)
        box('Thumb'+side,(sign*.341,-.048,.901),(.028,.04,.064),'skin','Hand.'+side)
    return parts
