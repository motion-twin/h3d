package h2d;
import h2d.col.Bounds;

private class CoreObjects  {
	
	public var tmpMatA : h3d.Vector;
	public var tmpMatB : h3d.Vector;
	public var tmpSize : h3d.Vector;
	public var tmpUVPos : h3d.Vector;
	public var tmpUVScale : h3d.Vector;
	public var tmpColor : h3d.Vector;
	public var tmpMatrix : h3d.Matrix;
	public var tmpMatrix2D : h2d.Matrix;
	public var tmpMatrix2D_2 : h2d.Matrix;
	public var tmpMaterial : h3d.mat.Material;
	public var planBuffer : h3d.impl.Buffer;
	public var tmpBounds : h2d.col.Bounds;
	
	var emptyTexture 	: h3d.mat.Texture;
	var emptyTile 		: h2d.Tile;
	var voidTile 		: h2d.Tile;
	var whiteTexture 	: h3d.mat.Texture;
	var voidTexture 	: h3d.mat.Texture;
	
	public function new() {
		tmpMatA = new h3d.Vector();
		tmpMatB = new h3d.Vector();
		tmpColor = new h3d.Vector();
		tmpSize = new h3d.Vector();
		tmpUVPos = new h3d.Vector();
		tmpUVScale = new h3d.Vector();
		tmpMatrix = new h3d.Matrix();
		tmpMatrix2D = new h2d.Matrix();
		tmpMatrix2D_2 = new h2d.Matrix();
		tmpBounds = new h2d.col.Bounds();
		tmpMaterial = new h3d.mat.Material(null);
		tmpMaterial.culling = None;
		tmpMaterial.depth(false, Always);
		
		var vector = new hxd.FloatBuffer();
		for( pt in [[0, 0], [1, 0], [0, 1], [1, 1]] ) {
			vector.push(pt[0]);
			vector.push(pt[1]);
			vector.push(pt[0]);
			vector.push(pt[1]);
		}
		
		planBuffer = h3d.Engine.getCurrent().mem.allocVector(vector, 4, 4);
	}
	
	public function getEmptyTile() {
		getEmptyTexture();
		return emptyTile;
	}
	
	public function getVoidTile() {
		getVoidTexture();
		return voidTile;
	}
	
	public function getEmptyTexture() {
		if( emptyTexture == null || emptyTexture.isDisposed() ) {
			if( emptyTexture != null ) emptyTexture.dispose();
			emptyTexture = h3d.mat.Texture.fromColor(0xffFF00FF);
			#if debug
			emptyTexture.name = 'emptyTexture';
			#end
			emptyTile = new Tile(emptyTexture, 0, 0, 1, 1);
		}
		return emptyTexture;
	}
	
	public function getWhiteTexture() {
		if( whiteTexture == null || whiteTexture.isDisposed() ) {
			if( whiteTexture != null ) whiteTexture.dispose();
			whiteTexture = h3d.mat.Texture.fromColor(0xFFFFFFFF);
			#if debug
			whiteTexture.name = 'whiteTexture';
			#end
		}
		return whiteTexture;
	}
	
	public function getVoidTexture() {
		if( voidTexture == null || voidTexture.isDisposed() ) {
			if( voidTexture != null ) voidTexture.dispose();
			voidTexture = h3d.mat.Texture.fromColor(0x0);
			#if debug
			voidTexture.name = 'voidTexture';
			#end
			voidTile = new Tile(voidTexture, 0, 0, 1, 1);
		}
		return voidTexture;
	}
	
	
}

class Tools {
	
	static var CORE : CoreObjects = null;
	
	public static function getEmptyTexture() 	return getCoreObjects().getEmptyTexture();
	public static function getVoidTexture() 	return getCoreObjects().getVoidTexture();
	
	public static function getVoidTile() 		return getCoreObjects().getVoidTile();
	public static function getEmptyTile() 		return getCoreObjects().getEmptyTile();
	public static function getWhiteTile() 		return new Tile(getCoreObjects().getWhiteTexture(), 0, 0, 4, 4);
	
	@:allow(h2d)
	static function getCoreObjects() : CoreObjects {
		var c = CORE;
		if( c == null ) {
			c = new CoreObjects();
			CORE = c;
		}
		return c;
	}
	
	@:allow(h2d)
	@:access(h3d.impl.BigBuffer)
	static function checkCoreObjects() {
		var c = CORE;
		if( c == null ) return;
		// if we have lost our context
		if( c.planBuffer.b.isDisposed() )
			CORE = null;
	}
	
}
