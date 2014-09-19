package h3d.prim;

class Quads extends Primitive {

	public var pts : Array<h3d.Vector>;
	var uvs : Array<UV>;
	var normals : Array<h3d.Vector>;
	
	var mem : hxd.FloatStack;
	var len : Null<Int> = null;
	
	public function new( pts, ?uvs, ?normals ) {
		this.pts = pts;
		this.uvs = uvs;
		this.normals = normals;
		mem = new hxd.FloatStack();
	}
	
	public function scale( x : Float, y : Float, z : Float ) {
		for( p in pts ) {
			p.x *= x;
			p.y *= y;
			p.z *= z;
		}
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
	
	public function addNormals() {
		throw "Not implemented";
	}
	
	override function alloc( engine : Engine ) {
		dispose();
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
		}
		var size = 3;
		if( normals != null ) size += 3;
		if( uvs != null ) size += 2;
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