package h2d;

import hxd.Assert;
import hxd.System;

@:allow(h2d.SpriteBatch)
class BatchElement {
	public var x : Float;
	public var y : Float;
	public var scale : Float;
	public var rotation(default,set) : Float; //setting this will trigger parent property
	public var alpha : Float;
	public var t : Tile;
	public var color : h3d.Vector;
	public var batch(default, null) : SpriteBatch;
	
	var prev : BatchElement;
	var next : BatchElement;
	
	function new(t) {
		x = 0; y = 0; alpha = 1;
		rotation = 0; scale = 1;
		color = new h3d.Vector(1, 1, 1, 1);
		this.t = t;
	}
	
	public inline function remove() {
		batch.delete(this);
	}
	
	inline function set_rotation(v) {
		if (v != 0.0) batch.hasRotationScale = true;
		return rotation = v;
	}
	
}

/**
 * You can enhance performances disabling vertexcolor/alpha etc
 */
class SpriteBatch extends Drawable {

	public var tile : Tile;
	public var hasRotationScale : Bool; // costs is nearly 0
	public var hasVertexColor(default,set) : Bool; //cost is heavy
	public var hasVertexAlpha(default,set) : Bool; //cost is heavy
	
	var first : BatchElement;
	var last : BatchElement;
	var tmpBuf : hxd.FloatBuffer;
		
	public function new(t,?parent) {
		super(parent);
		tile = t;
		
		hasVertexColor = true;
		hasRotationScale = true;
		hasVertexAlpha = true;
	}
	
	function set_hasVertexColor(b) {
		hasVertexColor=shader.hasVertexColor = b;
		return b;
	}
	
	function set_hasVertexAlpha(b) {
		hasVertexAlpha=shader.hasVertexAlpha = b;
		return b;
	}
	
	public function add(e:BatchElement) {
		e.batch = this;
		if( first == null )
			first = last = e;
		else {
			last.next = e;
			e.prev = last;
			last = e;
		}
		return e;
	}
	
	public function alloc(t) {
		return add(new BatchElement(t));
	}
	
	@:allow(h2d.BatchElement)
	function delete(e : BatchElement) {
		if( e.prev == null ) {
			if( first == e )
				first = e.next;
		} else
			e.prev.next = e.next;
		if( e.next == null ) {
			if( last == e )
				last = e.prev;
		} else
			e.next.prev = e.prev;
	}
	
	override function getMyBounds() {
		throw "retireving sprite batch size is meaningless";
		return null;
	}
	
	override function draw( ctx : RenderContext ) {
		if( first == null )
			return;
			
		if ( tmpBuf == null ) {
			tmpBuf = new hxd.FloatBuffer();
		}
		
		Assert.notNull( tmpBuf );
		
		var pos = 0;
		var e = first;
		var tmp = tmpBuf;
		while( e != null ) {
			var t = e.t;
			if( hasRotationScale ) {
				var ca = Math.cos(e.rotation), sa = Math.sin(e.rotation);
				var hx = t.width, hy = t.height;
				var px = t.dx, py = t.dy;
				tmp[pos++] = (px * ca + py * sa) * e.scale + e.x;
				tmp[pos++] = (py * ca - px * sa) * e.scale + e.y;
				tmp[pos++] = t.u;
				tmp[pos++] = t.v;
				if( hasVertexAlpha)
					tmp[pos++] = e.alpha;
				if ( hasVertexColor ) { 
					tmp[pos++] = e.color.x;
					tmp[pos++] = e.color.y;
					tmp[pos++] = e.color.z;
					tmp[pos++] = e.color.w;
				}
				var px = t.dx + hx, py = t.dy;
				tmp[pos++] = (px * ca + py * sa) * e.scale + e.x;
				tmp[pos++] = (py * ca - px * sa) * e.scale + e.y;
				tmp[pos++] = t.u2;
				tmp[pos++] = t.v;
				
				if( hasVertexAlpha)
					tmp[pos++] = e.alpha;
				if ( hasVertexColor ) { 
					tmp[pos++] = e.color.x;
					tmp[pos++] = e.color.y;
					tmp[pos++] = e.color.z;
					tmp[pos++] = e.color.w;
				}
				var px = t.dx, py = t.dy + hy;
				tmp[pos++] = (px * ca + py * sa) * e.scale + e.x;
				tmp[pos++] = (py * ca - px * sa) * e.scale + e.y;
				tmp[pos++] = t.u;
				tmp[pos++] = t.v2;
				if( hasVertexAlpha)
					tmp[pos++] = e.alpha;
				if ( hasVertexColor ) { 
					tmp[pos++] = e.color.x;
					tmp[pos++] = e.color.y;
					tmp[pos++] = e.color.z;
					tmp[pos++] = e.color.w;
				}
				var px = t.dx + hx, py = t.dy + hy;
				tmp[pos++] = (px * ca + py * sa) * e.scale + e.x;
				tmp[pos++] = (py * ca - px * sa) * e.scale + e.y;
				tmp[pos++] = t.u2;
				tmp[pos++] = t.v2;
				if( hasVertexAlpha)
					tmp[pos++] = e.alpha;
				if ( hasVertexColor ) { 
					tmp[pos++] = e.color.x;
					tmp[pos++] = e.color.y;
					tmp[pos++] = e.color.z;
					tmp[pos++] = e.color.w;
				}
			} else {
				var sx = e.x + t.dx;
				var sy = e.y + t.dy;
				tmp[pos++] = sx;
				tmp[pos++] = sy;
				tmp[pos++] = t.u;
				tmp[pos++] = t.v;
				if( hasVertexAlpha)
					tmp[pos++] = e.alpha;
				if ( hasVertexColor ) { 
					tmp[pos++] = e.color.x;
					tmp[pos++] = e.color.y;
					tmp[pos++] = e.color.z;
					tmp[pos++] = e.color.w;
				}
				
				tmp[pos++] = sx + t.width + 0.1;
				tmp[pos++] = sy;
				tmp[pos++] = t.u2;
				tmp[pos++] = t.v;
				if( hasVertexAlpha)
					tmp[pos++] = e.alpha;
				if ( hasVertexColor ) { 
					tmp[pos++] = e.color.x;
					tmp[pos++] = e.color.y;
					tmp[pos++] = e.color.z;
					tmp[pos++] = e.color.w;
				}
				
				tmp[pos++] = sx;
				tmp[pos++] = sy + t.height + 0.1;
				tmp[pos++] = t.u;
				tmp[pos++] = t.v2;
				if( hasVertexAlpha)
					tmp[pos++] = e.alpha;
				if ( hasVertexColor ) { 
					tmp[pos++] = e.color.x;
					tmp[pos++] = e.color.y;
					tmp[pos++] = e.color.z;
					tmp[pos++] = e.color.w;
				}
				
				tmp[pos++] = sx + t.width + 0.1;
				tmp[pos++] = sy + t.height + 0.1;
				tmp[pos++] = t.u2;
				tmp[pos++] = t.v2;
				if( hasVertexAlpha)
					tmp[pos++] = e.alpha;
				if ( hasVertexColor ) { 
					tmp[pos++] = e.color.x;
					tmp[pos++] = e.color.y;
					tmp[pos++] = e.color.z;
					tmp[pos++] = e.color.w;
				}
			}
			e = e.next;
		}
		
		var stride = 4;
		if ( hasVertexColor ) stride += 4;
		if ( hasVertexAlpha ) stride += 1;
		
		var nverts = Std.int(pos / stride);
		var buffer = ctx.engine.mem.alloc(nverts, stride, 4,true);
		
		hxd.Assert.notNull( tmpBuf );
		hxd.Assert.notNull( buffer );
		
		buffer.uploadVector(tmpBuf, 0, nverts);
		
		setupShader(ctx.engine, tile, Drawable.BASE_TILE_DONT_CARE);
		ctx.engine.renderQuadBuffer(buffer);
		buffer.dispose();
	}
	
	public inline function getElements() : Iterable<BatchElement> {
		var e = first;
		return {
			iterator: function() return 
				{
					next:function() {return e = e.next;},
					hasNext:function() { return e.next != null; },
				}
			};
	}
	
	//public static var spin = 0;
	
	public inline function isEmpty() {
		return first == null;
	}
	
}