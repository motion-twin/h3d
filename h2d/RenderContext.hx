package h2d;

class RenderContext {
	public var engine : h3d.Engine;
	public var time : Float;
	public var elapsedTime : Float;
	public var frame : Int;
	public var currentPass : Int = 0;
	public var buffer : hxd.FloatStack;
	public var shader : h2d.Drawable.DrawableShader;
	
	var currentObj : h2d.Drawable;
	var texture : h3d.mat.Texture;
	var tile : h2d.Tile;
	
	var stride : Int;
	
	public function new() {
		frame = 0;
		time = 0.;
		elapsedTime = 1. / hxd.Stage.getInstance().getFrameRate();
		buffer = new hxd.FloatStack();
	}
	
	public function reset() {
		texture = null;
		tile = null;
		currentObj = null;
		stride = 0;
		shader = null;
		buffer.reset();
	}
	
	public function begin() {
		reset();
	}
	
	public function end() {
		flush();
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

		var core = Tools.getCoreObjects();
		var tex = tile.getTexture();
		var tile = (tile == null) ? (new Tile(null, 0, 0, 4, 4)) : tile;
		
		shader.size = null;
		shader.uvPos = null;
		shader.uvScale = null;
		
		shader.matA.set(1.0, 0, 0);
		shader.matB.set(0, 1.0, 0);
		shader.tex = tile.getTexture();
		shader.isAlphaPremul = tex.alpha_premultiplied 
		&& (shader.hasAlphaMap || shader.hasAlpha || shader.hasMultMap 
		|| shader.hasVertexAlpha || shader.hasVertexColor 
		|| shader.colorMatrix != null || shader.colorAdd != null
		|| shader.colorMul != null );
		
		mat.shader = currentObj.shader;
		
		var cm = currentObj.writeAlpha ? 15 : 7;
		if( mat.colorMask != cm ) mat.colorMask = cm;
	
		engine.selectMaterial(mat);
	}
	
	public function flush(force=false) {
		if ( stride == 0 || buffer.length == 0 ) {
			reset();
			return;
		}
		
		beforeDraw();
		var tmp = engine.mem.allocStack( buffer, stride, 4, true);
		engine.renderQuadBuffer(tmp);
		tmp.dispose();
		
		reset();
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
		this.shader = obj.shader;
	}

}