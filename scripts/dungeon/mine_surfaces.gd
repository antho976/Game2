extends RefCounted
## Continuous cave banks and physical silt surfaces; shared vertices close tile seams.
static func cave(cells: Dictionary,parent: Node3D,material: Material) -> void:
	var edges: Array=[]
	var normals: Dictionary={}
	for c: Vector2i in cells:
		var p:=c*2
		for data in [[Vector2i.UP,p,p+Vector2i(2,0)],[Vector2i.RIGHT,p+Vector2i(2,0),p+Vector2i(2,2)],[Vector2i.DOWN,p+Vector2i(2,2),p+Vector2i(0,2)],[Vector2i.LEFT,p+Vector2i(0,2),p]]:
			if cells.has(c+data[0]):continue
			edges.append([data[1],data[2]])
			for point in [data[1],data[2]]:normals[point]=normals.get(point,Vector2.ZERO)+Vector2(data[0])
	for p in normals:normals[p]/=maxf(normals[p].length_squared()*.5,1)
	var noise:=FastNoiseLite.new()
	noise.seed=372
	noise.frequency=.36
	var rows:=[Vector2(-.52,0),Vector2(-.27,.26),Vector2(.02,.80),Vector2(.22,1.5),Vector2(.08,2.35),Vector2(.35,3.1),Vector2(.30,4.0),Vector2(.72,5.05),Vector2(.45,6.05),Vector2(0,7.2)]
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for edge in edges:
		for slice in range(4):
			var points: Array[Vector3]=[]
			var ns: Array[Vector3]=[]
			for row in rows.size():
				for end in range(2):
					var t: float=(slice+end)*.25
					var p: Vector2=Vector2(edge[0]).lerp(Vector2(edge[1]),t)
					var normal: Vector2=normals[edge[0]].lerp(normals[edge[1]],t)
					var jitter: float=noise.get_noise_3d(p.x,rows[row].y*.8,p.y)
					var offset: float=rows[row].x+jitter*.9*sin(float(row)/9*PI)
					var y: float=rows[row].y+jitter*.70*sin(float(row)/9*PI)
					y+=(bedrock_height(p,noise)-7.2)*pow(float(row)/9,3)
					var outline:=bedrock_outline(p,noise)-p
					var warp:=outline*pow(float(row)/9,2)
					points.append(Vector3(p.x+normal.x*offset+warp.x,y,p.y+normal.y*offset+warp.y))
					ns.append(Vector3(-normal.x,.12 if row<8 else .65,-normal.y).normalized())
			for row in rows.size()-1:
				for tri in [[row*2,row*2+1,row*2+3],[row*2,row*2+3,row*2+2]]:
					var face: Vector3=(points[tri[1]]-points[tri[0]]).cross(points[tri[2]]-points[tri[0]]).normalized()
					if face.dot(ns[tri[0]])<0:face=-face
					for i in [tri[0],tri[2],tri[1]]:
						surface.set_normal(face)
						surface.add_vertex(points[i])
	var instance:=MeshInstance3D.new()
	instance.name="ContinuousExcavatedBanks"
	instance.mesh=surface.commit()
	instance.material_override=material
	parent.add_child(instance)
	# A single irregular surface represents the uncut mass around the excavation.
	# No individual cube caps, grid seams or isolated perimeter stones.
	var mass:=SurfaceTool.new()
	mass.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Dense near the excavation, progressively coarser in the unseen distance.
	# The same height function closes the rim against the top of the cave banks.
	var xs:=backing_axis(-32,32)
	var zs:=backing_axis(-88,24)
	for ix in xs.size()-1:
		for iz in zs.size()-1:
			var x: float=xs[ix]
			var z: float=zs[iz]
			if cells.has(Vector2i(floori(x/2.0),floori(z/2.0))):continue
			var span:=Vector2(xs[ix+1]-x,zs[iz+1]-z)
			for corner in [Vector2(0,0),Vector2(1,1),Vector2(0,1),Vector2(0,0),Vector2(1,0),Vector2(1,1)]:
				var p: Vector2=Vector2(x,z)+corner*span
				var dx:=bedrock_height(p-Vector2(.1,0),noise)-bedrock_height(p+Vector2(.1,0),noise)
				var dz:=bedrock_height(p-Vector2(0,.1),noise)-bedrock_height(p+Vector2(0,.1),noise)
				mass.set_normal(Vector3(dx,.2,dz).normalized())
				var outline:=bedrock_outline(p,noise)
				mass.add_vertex(Vector3(outline.x,bedrock_height(p,noise),outline.y))
	var backing:=MeshInstance3D.new()
	backing.name="UnexcavatedBedrock"
	backing.mesh=mass.commit()
	backing.material_override=material
	# The cutaway cap does not cast real cave shadows. Avoid self-shadow acne
	# over its shallow slopes; the vertical banks still shade the excavation.
	backing.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(backing)

static func bedrock_outline(p: Vector2,noise: FastNoiseLite) -> Vector2:
	return p+Vector2(noise.get_noise_2d(p.x*.5,p.y*.5),noise.get_noise_2d(p.x*.5+45,p.y*.5-23))*.65

static func bedrock_height(p: Vector2,noise: FastNoiseLite) -> float:
	# Broad uneven masses and smaller broken ridges instead of a flat striped cap.
	return 7.2+noise.get_noise_2d(p.x*.36,p.y*.36)*1.65+absf(noise.get_noise_2d(p.x*1.4,p.y*1.4))*.65

static func backing_axis(low: int,high: int) -> PackedFloat32Array:
	var values:=PackedFloat32Array()
	for distance in [224,160,112,80,56,40,28,20,14,10,6,4,2]:values.append(low-distance)
	for value in range(low,high+1):values.append(value)
	for distance in [2,4,6,10,14,20,28,40,56,80,112,160,224]:values.append(high+distance)
	return values

static func drift(parent: Node3D,material: Material,pos: Vector3,radius: Vector2,height: float,seed_value: int) -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides:=32
	var rim: Array[float]=[]
	for i in sides:rim.append(rng.randf_range(.83,1.14))
	var vertices: Array[Vector3]=[]
	var normals: Array[Vector3]=[]
	for ring in range(5):
		var t: float=ring/4.0
		for i in sides:
			var a: float=i*TAU/sides
			var distance: float=t*rim[i]
			var h: float=height*pow(maxf(0,1-t*t),2)
			vertices.append(Vector3(cos(a)*distance*radius.x,h-.022,sin(a)*distance*radius.y))
			var slope: float=height*4*t*(1-t*t)
			normals.append(Vector3(cos(a)*slope/radius.x,1,sin(a)*slope/radius.y).normalized())
	for ring in range(4):
		for i in sides:
			var a:=ring*sides+i
			var b:=ring*sides+(i+1)%sides
			for index in [a,b+sides,b,a,a+sides,b+sides]:
				surface.set_normal(normals[index])
				surface.add_vertex(vertices[index])
	var instance:=MeshInstance3D.new()
	instance.name="DepositedSilt"
	instance.position=pos
	instance.mesh=surface.commit()
	instance.material_override=material
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	# Large banks are real slopes. Thin surface dressing shares the level's flat floor.
	if height>.24:instance.create_trimesh_collision()
