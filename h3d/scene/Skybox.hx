package h3d.scene;


class SkyboxMaterial extends h3d.mat.MeshMaterial{
	public var cubeTex : h3d.mat.Texture;
	public function new( t: h3d.mat.Texture ) {
		cubeTex = t;	
		super(null);
		culling = Back;
		depthTest = h3d.mat.Data.Compare.LessEqual;
		depthWrite = false;
		blendMode = None;
	}
	
	override function setup( ctx : h3d.scene.RenderContext ) {
		if( cubeTex!=null && cubeTex.isCubic ){
			mshader.cubeTexture 	= cubeTex;
			mshader.hasCubeTexture = true;
		}
		else 
			mshader.hasCubeTexture = false;
		super.setup(ctx);
	}
}

class Skybox extends h3d.scene.Mesh {
	public var smaterial : SkyboxMaterial;
	
	public function new(?t:h3d.mat.Texture, ?p) {
		var prim = new h3d.prim.Cube();
		for ( i in 0...prim.points.length ) {
			var pt = prim.points[i];
			pt.x *= 2.0; 
			pt.y *= 2.0; 
			pt.z *= 2.0; 
			pt.x -= 1.0;
			pt.y -= 1.0;
			pt.z -= 1.0;
		}
		super(prim,smaterial=new SkyboxMaterial(t), p);
	}
	
	override function sync( ctx : RenderContext) {
		x = ctx.camera.pos.x;
		y = ctx.camera.pos.y;
		z = ctx.camera.pos.z;
		setScale( ctx.camera.zFar * 0.5 );
		super.sync(ctx);
	}
	
	override function draw( ctx : RenderContext ) {
		
		super.draw(ctx);
	}
}

