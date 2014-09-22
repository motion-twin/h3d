package h3d.prim;

class Quads extends Primitive {

	public var pts 		: Array<h3d.Vector>;
	public var uvs		: Array<UV>;
	public var normals 	: Array<h3d.Vector>;
	public var colors	: Array<h3d.Vector>;
	
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
		for( p in pts ) {
			p.x *= x;
			p.y *= y;
			p.z *= z;
		}
	}
	
	var bounds :h3d.col.Bounds;
	public override function getBounds() {
		if ( bounds != null) return bounds;
		bounds = new h3d.col.Bounds();
		
		for ( p in pts)
			bounds.addPos( p.x,p.y,p.z );
			
		return bounds;
	}
	
	public function addTCoords() {
		uvs = [];
		var a = new UV(0, 1);
		var b = new UV(1, 1);
		var c = new UV(0, 0);
		var d = new UV(1, 0);
		for( i in 0...pts.length >> 2 ) {
			uvs.push(a);
			uvs.push(b);
			uvs.push(c);
			uvs.push(d);
		}
	}
	
	public function addColors() {
		colors = [];
		for( i in 0...pts.length >> 2 ) {
			colors.push(new h3d.Vector(1,1,1,1));
			colors.push(new h3d.Vector(1,1,1,1));
			colors.push(new h3d.Vector(1,1,1,1));
			colors.push(new h3d.Vector(1,1,1,1));
		}
	}
	
	
	public function addNormals() {
		throw "Not implemented";
	}
	
	override function alloc( engine : Engine ) {
		dispose();
		mem.reset();
		var v = mem;
		var l = (len != null) ? len : pts.length;
		for( i in 0...l ) {
			var pt = pts[i];
			v.push(pt.x);
			v.push(pt.y);
			v.push(pt.z); 
			
			if( uvs != null ) {
				var t = uvs[i];
				v.push(t.u);
				v.push(t.v);
			}
			
			if( normals != null ) {
				var n = normals[i];
				v.push(n.x);
				v.push(n.y);
				v.push(n.z);
			}
			
			if ( colors != null) {
				var c = colors[i];
				v.push(c.r);
				v.push(c.g);
				v.push(c.b);
				v.push(c.a);
			}
		}
		
		var size = 3;
		if( normals != null ) 	size += 3;
		if( uvs != null ) 		size += 2;
		if( colors != null ) 	size += 4;
		
		buffer = engine.mem.allocStack(v,size, 4);
	}
	
	public function getPoints() {
		return pts;
	}
	
	override function render(engine) {
		if( buffer == null || buffer.isDisposed() ) alloc(engine);
		engine.renderQuadBuffer(buffer);
	}
	
}