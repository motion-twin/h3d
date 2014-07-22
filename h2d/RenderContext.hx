package h2d;

class RenderContext {
	public var engine : h3d.Engine;
	public var time : Float;
	public var elapsedTime : Float;
	public var frame : Int;
	public var currentPass : Int = 0;
	public var buffer : hxd.FloatBuffer;
	public var bufPos : Int;
	
	var currentObj : h2d.Drawable;
	var texture : h3d.mat.Texture;
	var tile : h2d.Tile;
	
	var stride : Int;
	
	public function new() {
		frame = 0;
		time = 0.;
		elapsedTime = 1. / hxd.Stage.getInstance().getFrameRate();
		buffer = new hxd.FloatBuffer();
		bufPos = 0;
	}
	
	public function begin() {
		texture = null;
		tile = null;
		currentObj = null;
		bufPos = 0;
		stride = 0;
	}
	
	public function end() {
		flush();
		texture = null;		
		tile = null;
		currentObj = null;
		bufPos = 0;
		stride = 0;
	}
	
	public function beforeDraw() {
		var core = Tools.getCoreObjects();
		var mat = core.tmpMaterial;
		
		texture.filter = currentObj.filter ? Linear : Nearest;
		var isTexPremul  = texture.alpha_premultiplied;
		
		mat.depth( false, Always);
		
		switch( currentObj.blendMode ) {
			case Normal:
				mat.blend(isTexPremul ? One : SrcAlpha, OneMinusSrcAlpha);
			case None:
				mat.blend(One, Zero);
			case Add:
				mat.blend(isTexPremul ? One : SrcAlpha, One);
			case SoftAdd:
				mat.blend(OneMinusDstColor, One);
			case Multiply:
				mat.blend(DstColor, OneMinusSrcAlpha);
			case Erase:
				mat.blend(Zero, OneMinusSrcAlpha);
		}

		currentObj.prepareShaderEmission(engine,tile);
		
		mat.shader = currentObj.shader;
		var cm = currentObj.writeAlpha ? 15 : 7;
		if( mat.colorMask != cm ) mat.colorMask = cm;
	
		engine.selectMaterial(mat);
	}
	
	public function flush(force=false) {
		if ( stride == 0 || bufPos == 0 ) return;
		
		beforeDraw();
		var nverts = Std.int(bufPos / stride);
		var tmp = engine.mem.allocVector( buffer, stride, 4, true);
		engine.renderQuadBuffer(tmp);
		tmp.dispose();
		bufPos = 0;
		texture = null;
	}
	
	public function beginDraw(	obj : h2d.Drawable, nTile : h2d.Tile, ?nStride=4) {
		var nTexture = nTile.getTexture();
		
		if ( currentObj != null 
		&& (	nTexture != this.texture 
			|| 	nStride != this.stride 
			|| 	obj.blendMode != currentObj.blendMode 
			|| 	obj.filter != currentObj.filter) )
			flush();
		
		engine.selectShader(obj.shader);
		
		this.texture = nTexture;
		this.tile = nTile;
		this.stride = nStride;
		this.currentObj = obj;
	}

}