package h3d.prim;

/*
 * Warning this generates lot of gc pressure and required vectors might not be served 
 */
class StaticPackedQuads extends Primitive {

	public var 	pts 		: haxe.ds.Vector<hxd.Float32>;
	public var 	uvs			: haxe.ds.Vector<hxd.Float32>;
	public var 	normals 	: haxe.ds.Vector<hxd.Float32>;
	public var 	colors		: haxe.ds.Vector<hxd.Float32>;
	
	public var 	sendNormals = false;
	public var 	isDynamic = true;
	
	public var 	nbVertexToSend : Null<Int> = null;
	public var 	nbVertex = 0;
	var 		mem : hxd.FloatStack;
	
	public function new( nbVertex:Int, ?pts:Array<Float>, ?uvs:Array<Float>, ?normals:Array<Float>,?colors:Array<Float>) {
		this.nbVertex=nbVertex;
		
		mem = new hxd.FloatStack();
		
		this.pts = new haxe.ds.Vector(nbVertex*3);
		var i4 = 0;
		var z = 0.0;
		for( i in 0...(this.pts.length)>>2){
			this.pts[i4]	= z;
			this.pts[i4+1]	= z;
			this.pts[i4+2]	= z;
			this.pts[i4+3]	= z;
			i4+=4;
		}
		
		if( pts!=null)
			hxd.tools.VectorTools.blitArray( this.pts,pts);
		
		if( uvs!=null){
			addUV();
			hxd.tools.VectorTools.blitArray( this.uvs,uvs);
		}
		
		if( normals!=null){
			addNormal();
			hxd.tools.VectorTools.blitArray( this.normals,normals);
		}
		
		if( colors!=null){
			addColor();
			hxd.tools.VectorTools.blitArray( this.colors,colors);
		}
		
		mem.reserve( Std.int(this.pts.length) * stride() );
	}
	
	public function destroy(){
		dispose();
		mem=null;
		pts=null;
		uvs=null;
		normals=null;
		colors=null;
	}
	
	var bounds :h3d.col.Bounds;
	public override function getBounds() {
		if ( bounds != null) return bounds;
		bounds = new h3d.col.Bounds();
		for( i in 0...pts.length ) 
			bounds.addPos( pts[i*3],pts[i*3+1],pts[i*3+2] );
		return bounds;
	}
	
	public function addUV() {
		uvs = new haxe.ds.Vector( nbVertex * 2 );
		var i8 = 0;
		for( i in 0...nbVertex>>2 ) {
			i8 = i<<3;
			
			uvs[i8  ] = 0;
			uvs[i8+1] = 1;
			     
			uvs[i8+2] = 1;
			uvs[i8+3] = 1;
			          
			uvs[i8+4] = 0;
			uvs[i8+5] = 0;
			          
			uvs[i8+6] = 1;
			uvs[i8+7] = 0;
		}
	}
	
	public function addColor() {
		var z = 0.0;
		colors = new haxe.ds.Vector( nbVertex * 4 );
		for( i in 0...nbVertex ) {
			colors[(i<<2)	]	= z;
			colors[(i<<2)+1]	= z;
			colors[(i<<2)+2]	= z;
			colors[(i<<2)+3]	= z;
		}
	}

	
	public function addNormal() {
		var i = 1.0;
		normals = new haxe.ds.Vector( nbVertex * 3 );
		for( i in 0...nbVertex ) {
			normals[i*3]	= i;
			normals[i*3+1]	= i;
			normals[i*3+2]	= i;
		}
	}
	
	public inline function ptX(idx:Int) 	return pts[idx * 3];
	public inline function ptY(idx:Int) 	return pts[idx * 3 + 1];
	public inline function ptZ(idx:Int) 	return pts[idx * 3 + 2];
	
	public inline function nrmX(idx:Int) 	return normals[idx * 3];
	public inline function nrmY(idx:Int) 	return normals[idx * 3 + 1];
	public inline function nrmZ(idx:Int) 	return normals[idx * 3 + 2];
	
	public inline function uvU(idx:Int) 	return uvs[(idx <<1)		];
	public inline function uvV(idx:Int) 	return uvs[(idx << 1) + 1	];
	
	public inline function uvwU(idx:Int) 	return uvs[(idx * 3)		];
	public inline function uvwV(idx:Int) 	return uvs[(idx * 3) + 1	];
	public inline function uvwW(idx:Int) 	return uvs[(idx * 3) + 2	];
	
	public inline function colR(idx:Int) 	return colors[(idx<<2)		];
	public inline function colG(idx:Int) 	return colors[(idx<<2)+1	];
	public inline function colB(idx:Int) 	return colors[(idx<<2)+2	];
	public inline function colA(idx:Int) 	return colors[(idx<<2)+3	];
	
	public inline function setVertex( idx:Int, x, y, z){
		#if debug
		if( idx > nbVertex)
			throw "not enough vector space" ;
		#end
		pts[idx*3	] 	= x;
		pts[idx*3+1	] 	= y;
		pts[idx*3+2	] 	= z;
	}
	
	public inline function setNormal( idx:Int, x, y, z){
		#if debug
		if( idx > nbVertex)
			throw "not enough vector space" ;
		#end
		normals[idx * 3	] 	= x;
		normals[idx * 3+1] 	= y;
		normals[idx * 3+2] 	= z;
	}
	
	public inline function setUV( idx:Int, u, v){
		#if debug
		if( idx > nbVertex)
			throw "not enough vector space" ;
		#end
		uvs[(idx <<1)		] 	= u;
		uvs[(idx <<1) + 1	] 	= v;
	}
	
	
	public inline function setColor( idx:Int, r, g, b, a){
		#if debug
		if( idx > nbVertex)
			throw "not enough vector space" ;
		#end
		colors[(idx<<2)		] 	= r;
		colors[(idx<<2)+1	] 	= g;
		colors[(idx<<2)+2	] 	= b;
		colors[(idx<<2)+3	] 	= a;
	}
	
	@:noDebug
	override function alloc( engine : Engine ) {
		dispose();
		mem.reset();
		mem.reserve( nbVertex * stride() );
		
		var v = mem;
		var l = (nbVertexToSend != null) ? nbVertexToSend : nbVertex;
		
		for ( i in 0...l ) {
			v.push(ptX(i));
			v.push(ptY(i));
			v.push(ptZ(i)); 
			
			if( uvs != null ) {
				var t = uvs[i];
				v.push(uvU(i));
				v.push(uvV(i));
			}
			
			if( sendNormals && normals != null ) {
				v.push(nrmX(i));
				v.push(nrmY(i));
				v.push(nrmZ(i));
			}
			
			if ( colors != null) {
				v.push(colR(i));
				v.push(colG(i));
				v.push(colB(i));
				v.push(colA(i));
			}
		}
		
		buffer = engine.mem.allocStack(v, stride(), 4, isDynamic);
	}
	
	inline function stride() {
		var size = 3;
		if( sendNormals&&normals != null ) 	size += 3;
		if( uvs != null ) 					size += 2;
		if( colors != null ) 				size += 4;
		return size;
	}
	
	override function render(engine) {	
		if( buffer == null || buffer.isDisposed() ) alloc(engine);
		engine.renderQuadBuffer(buffer);
	}
	
}