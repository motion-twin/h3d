package h2d;

import h2d.SpriteBatch.BatchElement;
import haxe.Timer;
import hxd.Assert;
import hxd.FloatBuffer;
import hxd.System;

@:allow(h2d.SpriteBatch)
class BatchElement {
	
	/**
	 * call changePriority to update the priorty
	 */
	public var priority(default,null) : Int;
	
	public var x : Float;
	public var y : Float;
	
	public var sx : Float;
	public var sy : Float;
	
	public var rotation : Float; //setting this will trigger parent property
	public var alpha : Float;
	public var t : Tile;
	public var color : h3d.Vector;
	public var batch(default, null) : SpriteBatch;
	
	var prev : BatchElement;
	var next : BatchElement;
	
	function new( t : h2d.Tile) {
		x = 0; y = 0; alpha = 1;
		rotation = 0; sx = sy = 1;
		priority = 0;
		color = new h3d.Vector(1, 1, 1, 1);
		this.t = t;
	}
	
	public inline function remove() {
		batch.delete(this);
	}
	
	public var width(get, set):Float;
	public var height(get, set):Float;
	
	inline function get_width() return sx * t.width;
	inline function get_height() return sy * t.height;
	
	/**
	 * will allways keep ratio
	 */
	inline function set_width(w:Float) {
		sx = w / t.width;
		#if debug
		Assert.isTrue(batch.hasRotationScale);
		#end
		return w;
	}
	
	/**
	 * * will allways keep ratio
	 */
	inline function set_height(h:Float) {
		sy = h / t.height;
		#if debug
		Assert.isTrue(batch.hasRotationScale);
		#end
		return h;
	}
	
	public inline function changePriority(v) {
		this.priority = v;
		if ( batch != null)
		{
			batch.delete(this);
			batch.add( this, v );
		}
		return v;
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
		
		tmpMatrix = new Matrix();
	}
	
	function set_hasVertexColor(b) {
		hasVertexColor=shader.hasVertexColor = b;
		return b;
	}
	
	function set_hasVertexAlpha(b) {
		hasVertexAlpha=shader.hasVertexAlpha = b;
		return b;
	}
	
	/**
	 * 
	 * @param	?prio
	 */
	public function add(e:BatchElement, ?prio : Int) {
		e.batch = this;
		e.priority = prio;
		if ( prio == null )
		{
			if( first == null )
				first = last = e;
			else {
				last.next = e;
				e.prev = last;
				last = e;
			}
		}
		else {
			if( first == null ){
				first = last = e;
			}
			else {
				var cur = first;
				while ( e.priority < cur.priority && cur.next != null)
					cur = cur.next;
					
				if ( cur.next == null ) {
					if ( cur.priority >= e.priority) {
						cur.next = e;
						e.prev = cur;
						
						if( last == cur)
							last = e;
						if ( first == cur )
							first = cur;
					}
					else {
						e.next = cur;
						e.prev = cur.prev;
						if( cur.prev!=null)
							cur.prev.next = e;
						cur.prev = e;
						if( first ==cur )
							first = e;
						if( last == cur )
							last = cur;
					}
				}
				else {
					var p = cur.prev;
					var n = cur;
					e.next = cur;
					cur.prev = e;
					e.prev = p;
					if ( p != null) 
						p.next = e;
						
					if ( p == null )
						first = e;
				}
			}
		}
		return e;
	}
	
	/**
	 * no prio, means sprite will be pushed to back
	 * priority means higher is farther
	 */
	public function alloc(t:h2d.Tile,?prio:Int) {
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
			
		e.prev = null;
		e.next = null;
	}
	
	override function getMyBounds() {
		throw "retireving sprite batch size is meaningless";
		return null;
	}
	
	public inline function pushElemSRT( tmp : FloatBuffer, e:BatchElement, pos :Int) {
		var t = e.t;
		var px = t.dx, py = t.dy;
		var hx = e.t.width;
		var hy = e.t.height;
		
		tmpMatrix.identity();
		tmpMatrix.scale(e.sx, e.sy);
		tmpMatrix.rotate(e.rotation);
		tmpMatrix.translate(e.x, e.y);
		
		tmp[pos++] = tmpMatrix.transformPointX(px, py);// (px * ca + py * sa) * e.scale + e.x;
		tmp[pos++] = tmpMatrix.transformPointY(px, py);
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
		tmp[pos++] = tmpMatrix.transformPointX(px, py);
		tmp[pos++] = tmpMatrix.transformPointY(px, py);
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
		tmp[pos++] = tmpMatrix.transformPointX(px, py);
		tmp[pos++] = tmpMatrix.transformPointY(px, py);
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
		tmp[pos++] = tmpMatrix.transformPointX(px, py);
		tmp[pos++] = tmpMatrix.transformPointY(px, py);
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
		
		return pos;
	}
	
	public inline function pushElem( tmp : FloatBuffer, e:BatchElement, pos :Int) {
		var t = e.t;
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
		
		return pos;
	}
	
	var tmpMatrix:Matrix;
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
		
		var a, b, c, d = 0;
		
		if( hasRotationScale ){
			while( e != null ) {
				pos = pushElemSRT( tmp,e, pos);
				e = e.next;
			}
		}
		else {
			while( e != null ) {
				pos = pushElem( tmp,e, pos);
				e = e.next;
			}
		}
		
		var stride = 4;
		if ( hasVertexColor ) stride += 4;
		if ( hasVertexAlpha ) stride += 1;
		
		var nverts = Std.int(pos / stride);
		var buffer = ctx.engine.mem.alloc(nverts, stride, 4,true);
		
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
					next:function() { var cur = e ; e = e.next; return cur; },
					hasNext:function() { return e != null; },
				}
			};
	}
	
	//public static var spin = 0;
	
	public inline function isEmpty() {
		return first == null;
	}
	
}