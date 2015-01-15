package h3d.prim;
import hxd.Float32;

/*
 * Warning this generates lot of gc pressure and required vectors might not be served 
 */
class PackedQuads extends Primitive {

	public var pts 		: Array<hxd.Float32>;
	public var uvs		: Array<hxd.Float32>;
	public var normals 	: Array<hxd.Float32>;
	public var colors	: Array<hxd.Float32>;
	
	public var len : Null<Int> = null;
	var mem : hxd.FloatStack;
	
	public function new( pts, ?uvs, ?normals,?colors) {
		this.pts = pts;
		this.uvs = uvs;
		this.normals = normals;
		this.colors = colors;
		mem = new hxd.FloatStack();
	}
	
	public function scale( x : Float, y : Float, z : Float ) {
		for( i in 0...pts.length ) {
			pts[i * 3] 		*= x;
			pts[i * 3+1] 	*= y;
			pts[i * 3+2] 	*= z;
		}
	}
	
	var bounds :h3d.col.Bounds;
	public override function getBounds() {
		if ( bounds != null) return bounds;
		bounds = new h3d.col.Bounds();
		for( i in 0...pts.length ) 
			bounds.addPos( pts[i * 3],pts[i * 3+1],pts[i * 3+2] );
			
		return bounds;
	}
	
	public inline function nbVertex() {
		return Math.round( pts.length / 3 );
	}
	
	public function addTCoords() {
		uvs = [];
		for( i in 0...nbVertex()>>2 ) {
			uvs.push(0);
			uvs.push(1);
			
			uvs.push(1);
			uvs.push(1);
			
			uvs.push(0);
			uvs.push(0);
			
			uvs.push(1);
			uvs.push(0);
		}
	}
	
	function addX4(buf,v) {
		buf.push(v);
		buf.push(v);
		buf.push(v);
		buf.push(v);
	}
	
	public function addColors() {
		colors = [];
		for( i in 0...nbVertex()>>2 ) {
			addX4( colors, 1);
			addX4( colors, 1);
			addX4( colors, 1);
			addX4( colors, 1);
		}
	}
	
	public function addNormals() {
		throw "Not implemented";
	}
	
	public inline function ptX(idx) return pts[idx * 3];
	public inline function ptY(idx) return pts[idx * 3 + 1];
	public inline function ptZ(idx) return pts[idx * 3 + 2];
	
	public inline function nrmX(idx) return normals[idx * 3];
	public inline function nrmY(idx) return normals[idx * 3 + 1];
	public inline function nrmZ(idx) return normals[idx * 3 + 2];
	
	public inline function uvU(idx) return 	uvs[idx * 2];
	public inline function uvV(idx) return 	uvs[idx * 2 + 1];
	
	public inline function colR(idx) return colors[idx * 4];
	public inline function colG(idx) return colors[idx * 4 + 1];
	public inline function colB(idx) return colors[idx * 4 + 2];
	public inline function colA(idx) return colors[idx * 4 + 3];
	
	public inline function setVertex( idx, x, y, z){
		pts[idx * 3] 	= x;
		pts[idx * 3+1] 	= y;
		pts[idx * 3+2] 	= z;
	}
	
	public inline function setUV( idx, u, v){
		uvs[idx * 2] 		= u;
		uvs[idx * 2 + 1] 	= v;
	}
	
	public inline function setColor( idx, r, g, b, a){
		colors[idx * 4] 	= r;
		colors[idx * 4+1] 	= g;
		colors[idx * 4+2] 	= b;
		colors[idx * 4+3] 	= a;
	}
	
	override function alloc( engine : Engine ) {
		dispose();
		mem.reset();
		var v = mem;
		var l = (len != null) ? len*4 : pts.length;
		for ( i in 0...l ) {
			v.push(ptX(i));
			v.push(ptY(i));
			v.push(ptZ(i)); 
			
			if( uvs != null ) {
				var t = uvs[i];
				v.push(uvU(i));
				v.push(uvV(i));
			}
			
			if( normals != null ) {
				v.push(nrmX(i));
				v.push(nrmY(i));
				v.push(nrmZ(i));
			}
			
			if ( colors != null) {
				var c = colors[i];
				v.push(colR(i));
				v.push(colG(i));
				v.push(colB(i));
				v.push(colA(i));
			}
		}
		
		var size = 3;
		if( normals != null ) 	size += 3;
		if( uvs != null ) 		size += 2;
		if( colors != null ) 	size += 4;
		
		buffer = engine.mem.allocStack(v,size, 4);
	}
	
	override function render(engine) {
		if( buffer == null || buffer.isDisposed() ) alloc(engine);
		engine.renderQuadBuffer(buffer);
	}
	
}