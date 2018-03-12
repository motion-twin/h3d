package h2d;

private class ElementsIterator {
	var e : BatchElement;
	public inline function new(e) {
		this.e = e;
	}
	public inline function hasNext() {
		return e != null;
	}
	public inline function next() {
		var n = e;
		e = @:privateAccess e.next;
		return n;
	}
}

@:allow(h2d.SpriteBatch)
class BatchElement {
	public var x : Float;
	public var y : Float;
	public var scale(never,set) : Float;
	public var scaleX : Float;
	public var scaleY : Float;
	public var rotation : Float;
	public var r : Float;
	public var g : Float;
	public var b : Float;
	public var a : Float;
	public var t : Tile;
	public var alpha(get,set) : Float;
	public var visible : Bool;
	public var batch(default, null) : SpriteBatch;

	var prev : BatchElement;
	var next : BatchElement;

	public function new(t) {
		x = 0; y = 0; r = 1; g = 1; b = 1; a = 1;
		rotation = 0; scaleX = scaleY = 1;
		visible = true;
		this.t = t;
	}

	inline function set_scale(v) {
		return scaleX = scaleY = v;
	}

	inline function get_alpha() {
		return a;
	}

	inline function set_alpha(v) {
		return a = v;
	}

	function update(et:Float) {
		return true;
	}

	public function remove() {
		if( batch != null )
			batch.delete(this);
	}

}

class BasicElement extends BatchElement {

	public var vx : Float = 0.;
	public var vy : Float = 0.;
	public var friction : Float = 1.;
	public var gravity : Float = 0.;

	override function update(dt:Float) {
		vy += gravity * dt;
		x += vx * dt;
		y += vy * dt;
		if( friction != 1 ) {
			var p = Math.pow(friction, dt * 60);
			vx *= p;
			vy *= p;
		}
		return true;
	}

}

class SpriteBatch extends Drawable {

	public var tile : Tile;
	public var hasRotationScale : Bool;
	public var hasUpdate : Bool;
	var first : BatchElement;
	var last : BatchElement;
	var tmpBuf : hxd.FloatBuffer;
	var buffer : h3d.Buffer;
	var bufferVertices : Int;

	public function new(t,?parent) {
		super(parent);
		tile = t;
	}

	public function add(e:BatchElement,before=false) {
		e.batch = this;
		if( first == null ) {
			first = last = e;
			e.prev = e.next = null;
		} else if( before ) {
			e.prev = null;
			e.next = first;
			first.prev = e;
			first = e;
		} else {
			last.next = e;
			e.prev = last;
			e.next = null;
			last = e;
		}
		return e;
	}

	public function clear() {
		first = last = null;
		flush();
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
		e.batch = null;
	}

	override function sync(ctx) {
		super.sync(ctx);
		if( hasUpdate ) {
			var e = first;
			while( e != null ) {
				if( !e.update(ctx.elapsedTime) )
					e.remove();
				e = e.next;
			}
		}
		flush();
	}

	override function getBoundsRec( relativeTo, out, forSize ) {
		super.getBoundsRec(relativeTo, out, forSize);
		var e = first;
		while( e != null ) {
			var t = e.t;
			if( hasRotationScale ) {
				var ca = Math.cos(e.rotation), sa = Math.sin(e.rotation);
				var hx = t.width, hy = t.height;
				var px = t.dx * e.scaleX, py = t.dy * e.scaleY;
				var x, y;

				x = px * ca - py * sa + e.x;
				y = py * ca + px * sa + e.y;
				addBounds(relativeTo, out, x, y, 1e-10, 1e-10);

				var px = (t.dx + hx) * e.scaleX, py = t.dy * e.scaleY;
				x = px * ca - py * sa + e.x;
				y = py * ca + px * sa + e.y;
				addBounds(relativeTo, out, x, y, 1e-10, 1e-10);

				var px = t.dx * e.scaleX, py = (t.dy + hy) * e.scaleY;
				x = px * ca - py * sa + e.x;
				y = py * ca + px * sa + e.y;
				addBounds(relativeTo, out, x, y, 1e-10, 1e-10);

				var px = (t.dx + hx) * e.scaleX, py = (t.dy + hy) * e.scaleY;
				x = px * ca - py * sa + e.x;
				y = py * ca + px * sa + e.y;
				addBounds(relativeTo, out, x, y, 1e-10, 1e-10);
			} else
				addBounds(relativeTo, out, e.x + t.dx, e.y + t.dy, t.width, t.height);
			e = e.next;
		}
	}

	function flush() {
		if( first == null ){
			bufferVertices = 0;
			return;
		}
		if( tmpBuf == null ) tmpBuf = new hxd.FloatBuffer();
		var pos = 0;
		var e = first;
		var tmp = tmpBuf;
		while( e != null ) {
			if( !e.visible ) {
				e = e.next;
				continue;
			}

			var t = e.t;

			tmp.grow(pos + 8 * 4);

			var r : hxd.impl.Float32 = e.r, g : hxd.impl.Float32 = e.g, b : hxd.impl.Float32 = e.b, a : hxd.impl.Float32 = e.a;
			var u : hxd.impl.Float32 = t.u, v : hxd.impl.Float32 = t.v, u2 : hxd.impl.Float32 = t.u2, v2 : hxd.impl.Float32 = t.v2;
			if( hasRotationScale ) {
				var ca = Math.cos(e.rotation), sa = Math.sin(e.rotation);
				var hx = t.width, hy = t.height;
				var px = t.dx * e.scaleX, py = t.dy * e.scaleY;
				tmp[pos++] = px * ca - py * sa + e.x;
				tmp[pos++] = py * ca + px * sa + e.y;
				tmp[pos++] = u;
				tmp[pos++] = v;
				tmp[pos++] = r;
				tmp[pos++] = g;
				tmp[pos++] = b;
				tmp[pos++] = a;
				var px = (t.dx + hx) * e.scaleX, py = t.dy * e.scaleY;
				tmp[pos++] = px * ca - py * sa + e.x;
				tmp[pos++] = py * ca + px * sa + e.y;
				tmp[pos++] = u2;
				tmp[pos++] = v;
				tmp[pos++] = r;
				tmp[pos++] = g;
				tmp[pos++] = b;
				tmp[pos++] = a;
				var px = t.dx * e.scaleX, py = (t.dy + hy) * e.scaleY;
				tmp[pos++] = px * ca - py * sa + e.x;
				tmp[pos++] = py * ca + px * sa + e.y;
				tmp[pos++] = u;
				tmp[pos++] = v2;
				tmp[pos++] = r;
				tmp[pos++] = g;
				tmp[pos++] = b;
				tmp[pos++] = a;
				var px = (t.dx + hx) * e.scaleX, py = (t.dy + hy) * e.scaleY;
				tmp[pos++] = px * ca - py * sa + e.x;
				tmp[pos++] = py * ca + px * sa + e.y;
				tmp[pos++] = u2;
				tmp[pos++] = v2;
				tmp[pos++] = r;
				tmp[pos++] = g;
				tmp[pos++] = b;
				tmp[pos++] = a;
			} else {
				var sx = e.x + t.dx;
				var sy = e.y + t.dy;
				tmp[pos++] = sx;
				tmp[pos++] = sy;
				tmp[pos++] = u;
				tmp[pos++] = v;
				tmp[pos++] = r;
				tmp[pos++] = g;
				tmp[pos++] = b;
				tmp[pos++] = a;
				tmp[pos++] = sx + t.width + 0.1;
				tmp[pos++] = sy;
				tmp[pos++] = u2;
				tmp[pos++] = v;
				tmp[pos++] = r;
				tmp[pos++] = g;
				tmp[pos++] = b;
				tmp[pos++] = a;
				tmp[pos++] = sx;
				tmp[pos++] = sy + t.height + 0.1;
				tmp[pos++] = u;
				tmp[pos++] = v2;
				tmp[pos++] = r;
				tmp[pos++] = g;
				tmp[pos++] = b;
				tmp[pos++] = a;
				tmp[pos++] = sx + t.width + 0.1;
				tmp[pos++] = sy + t.height + 0.1;
				tmp[pos++] = u2;
				tmp[pos++] = v2;
				tmp[pos++] = r;
				tmp[pos++] = g;
				tmp[pos++] = b;
				tmp[pos++] = a;
			}
			e = e.next;
		}
		bufferVertices = pos>>3;
		if( buffer != null && !buffer.isDisposed() ) {
			if( buffer.vertices >= bufferVertices ){
				buffer.uploadVector(tmpBuf, 0, bufferVertices);
				return;
			}
			buffer.dispose();
			buffer = null;
		}
		if( bufferVertices > 0 )
			buffer = h3d.Buffer.ofSubFloats(tmpBuf, 8, bufferVertices, [Dynamic, Quads, RawFormat]);
	}

	override function draw( ctx : RenderContext ) {
		drawWith(ctx, this);
	}

	@:allow(h2d)
	function drawWith( ctx:RenderContext, obj : Drawable ) {
		if( first == null || buffer == null || buffer.isDisposed() || bufferVertices == 0 ) return;
		if( !ctx.beginDrawObject(obj, tile.getTexture()) ) return;
		ctx.engine.renderQuadBuffer(buffer, 0, bufferVertices>>1);
	}

	public inline function isEmpty() {
		return first == null;
	}

	public inline function getElements() {
		return new ElementsIterator(first);
	}

	override function onRemove()  {
		super.onRemove();
		if( buffer != null ) {
			buffer.dispose();
			buffer = null;
		}
	}
}