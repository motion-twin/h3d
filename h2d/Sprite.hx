package h2d;

import h2d.col.Bounds;
import h2d.col.Circle;
import h2d.col.Point;

import hxd.Math;

@:allow(h2d.Tools)
@:allow(h2d.Drawable)
class Sprite {

	public var 	name:String;
	var 		childs : Array<Sprite>;
	public var 	parent(default, null) : Sprite;
	public var 	numChildren(get, never) : Int;
	
	public var 	x(default,set) : hxd.Float32;
	public var 	y(default, set) : hxd.Float32;
		
	public var 	scaleX(default,set) : hxd.Float32 = 1.0;
	public var 	scaleY(default, set) : hxd.Float32 = 1.0;
		
	public var 	skewX(default,set) : hxd.Float32 = 0.0;
	public var 	skewY(default, set) : hxd.Float32 = 0.0;
	
	/**
	 * In radians
	 */
	public var rotation(default, set) : Float;
	public var visible : Bool;

	public var matA(default,null) 	: hxd.Float32;
	public var matB(default,null)	: hxd.Float32;
	public var matC(default,null)	: hxd.Float32;
	public var matD(default,null)	: hxd.Float32;
	public var absX(default,null)	: hxd.Float32;
	public var absY(default,null)	: hxd.Float32;
	
	var posChanged(default,set) : Bool;
	var allocated : Bool;
	var lastFrame : Int;
	
	public var  mouseX(get, null) : Float;
	public var  mouseY(get, null) : Float;
	
	#if alpha_inherit
	@:isVar
	public var 	alpha(get,set) : Float; 		public function get_alpha() { return alpha; }
	#end
	
	/**
	 * COSTS AN ARM
	 * retrieving this is costy because parenthood might need caching and a tranforms will have to be computed according to content
	 * on some object the setter will just explode at your face
	 * better code, could cache the getBounds result
	 */
	@:isVar
	public var width(get, set) : Float;
	
	/**
	 * COSTS AN ARM
	 * retrieving this is costy because parenthood might need caching and a tranforms will have to be computed according to content
	 * on some object the setter will just explode at your face
	 * better code, could cache the getBounds result
	 */
	@:isVar
	public var height(get, set) : Float;
	
	public var stage(get, null) : hxd.Stage;
	
	public function new( ?parent : Sprite ) {
		matA = 1; matB = 0; matC = 0; matD = 1; absX = 0; absY = 0;
		x = 0; y = 0; scaleX = 1; scaleY = 1; rotation = 0;
		skewX = 0; skewY = 0;
		
		posChanged = true;
		visible = true;
		childs = [];
		if( parent != null )
			parent.addChild(this);
	}

	public function getBounds( ?relativeTo : Sprite, ?out : h2d.col.Bounds ) : h2d.col.Bounds {
		if( out == null ) out = new h2d.col.Bounds();
		if( relativeTo == null ) {
			relativeTo = getScene();
			if( relativeTo == null )
				relativeTo = new Sprite();
		} else {
			var s1 = getScene();
			var s2 = relativeTo.getScene();
			if( s1 != s2 ) {
				// if we are getting the bounds relative to a scene
				// were are not into, it's the same as taking absolute position
				if( s1 == null && s2 == relativeTo )
					relativeTo = new Sprite();
				else if( s2 == null )
					throw "Cannot getBounds() with a relative element not in the scene";
				else
					throw "Cannot getBounds() with a relative element in a different scene";
			}
			relativeTo.syncPos();
		}
		syncPos();
		getBoundsRec(relativeTo, out);
		if( out.isEmpty() ) {
			addBounds(relativeTo, out, 0, 0, 1, 1);
			out.xMax = out.xMin;
			out.yMax = out.yMin;
		}
		return out;
	}
	
	function getBoundsRec( relativeTo : Sprite, out : h2d.col.Bounds ) {
		syncPos();
		
		var n = childs.length;
		if( n == 0 ) {
			out.empty();
			return;
		}
		if( posChanged ) {
			calcAbsPos();
			for( c in childs )
				c.posChanged = true;
			posChanged = false;
		}
		if( n == 1 ) {
			childs[0].getBounds(relativeTo, out);
			return;
		}
		var xmin = hxd.Math.POSITIVE_INFINITY, ymin = hxd.Math.POSITIVE_INFINITY;
		var xmax = hxd.Math.NEGATIVE_INFINITY, ymax = hxd.Math.NEGATIVE_INFINITY;
		for ( c in childs ) {
			
			c.getBoundsRec(relativeTo, out);
			if( out.xMin < xmin ) xmin = out.xMin;
			if( out.yMin < ymin ) ymin = out.yMin;
			if( out.xMax > xmax ) xmax = out.xMax;
			if( out.yMax > ymax ) ymax = out.yMax;
		}
		out.xMin = xmin;
		out.yMin = ymin;
		out.xMax = xmax;
		out.yMax = ymax;
	}

	function addBounds( relativeTo : Sprite, out : h2d.col.Bounds, dx : Float, dy : Float, width : Float, height : Float ) {

		if( width <= 0 || height <= 0 ) return;

		if( relativeTo == this ) {
			if( out.xMin > dx ) out.xMin = dx;
			if( out.yMin > dy ) out.yMin = dy;
			if( out.xMax < dx + width ) out.xMax = dx + width;
			if( out.yMax < dy + height ) out.yMax = dy + height;
			return;
		}

		var det = 1 / (relativeTo.matA * relativeTo.matD - relativeTo.matB * relativeTo.matC);
		var rA = relativeTo.matD * det;
		var rB = -relativeTo.matB * det;
		var rC = -relativeTo.matC * det;
		var rD = relativeTo.matA * det;
		var rX = absX - relativeTo.absX;
		var rY = absY - relativeTo.absY;

		var x, y, rx, ry;

		x = dx * matA + dy * matC + rX;
		y = dx * matB + dy * matD + rY;
		rx = x * rA + y * rC;
		ry = x * rB + y * rD;
		if( out.xMin > rx ) out.xMin = rx;
		if( out.yMin > ry ) out.yMin = ry;
		if( out.xMax < rx ) out.xMax = rx;
		if( out.yMax < ry ) out.yMax = ry;

		x = (dx + width) * matA + dy * matC + rX;
		y = (dx + width) * matB + dy * matD + rY;
		rx = x * rA + y * rC;
		ry = x * rB + y * rD;
		if( out.xMin > rx ) out.xMin = rx;
		if( out.yMin > ry ) out.yMin = ry;
		if( out.xMax < rx ) out.xMax = rx;
		if( out.yMax < ry ) out.yMax = ry;

		x = dx * matA + (dy + height) * matC + rX;
		y = dx * matB + (dy + height) * matD + rY;
		rx = x * rA + y * rC;
		ry = x * rB + y * rD;
		if( out.xMin > rx ) out.xMin = rx;
		if( out.yMin > ry ) out.yMin = ry;
		if( out.xMax < rx ) out.xMax = rx;
		if( out.yMax < ry ) out.yMax = ry;

		x = (dx + width) * matA + (dy + height) * matC + rX;
		y = (dx + width) * matB + (dy + height) * matD + rY;
		rx = x * rA + y * rC;
		ry = x * rB + y * rD;
		if( out.xMin > rx ) out.xMin = rx;
		if( out.yMin > ry ) out.yMin = ry;
		if( out.xMax < rx ) out.xMax = rx;
		if( out.yMax < ry ) out.yMax = ry;
	}
	
	public function getSpritesCount() {
		var k = 0;
		for( c in childs )
			k += c.getSpritesCount() + 1;
		return k;
	}
	
	public inline function set_posChanged(v) {
		posChanged = v;
		if( v && childs!=null)
			for ( c in childs)
				c.posChanged = v;
		return posChanged;
	}
	/**
	 * 
	 * @param	?pt if pt is null a pt will be newed
	 */
	public function localToGlobal( ?pt : h2d.col.Point ) {
		syncPos();
		if( pt == null ) pt = new h2d.col.Point();
		var px = pt.x * matA + pt.y * matC + absX;
		var py = pt.x * matB + pt.y * matD + absY;
		pt.x = (px + 1) * 0.5;
		pt.y = (1 - py) * 0.5;
		var scene = getScene();
		if( scene != null ) {
			pt.x *= scene.width;
			pt.y *= scene.height;
		} else {
			pt.x *= hxd.System.width;
			pt.y *= hxd.System.height;
		}
		return pt;
	}

	public function globalToLocal( pt : h2d.col.Point ) {
		syncPos();
		var scene = getScene();
		if( scene != null ) {
			pt.x /= scene.width;
			pt.y /= scene.height;
		} else {
			pt.x /= hxd.System.width;
			pt.y /= hxd.System.height;
		}
		pt.x = pt.x * 2 - 1;
		pt.y = 1 - pt.y * 2;
		pt.x -= absX;
		pt.y -= absY;
		var invDet = 1.0 / (matA * matD - matB * matC);
		var px = (pt.x * matD - pt.y * matC) * invDet;
		var py = (-pt.x * matB + pt.y * matA) * invDet;
		pt.x = px;
		pt.y = py;
		return pt;
	}
	
	function getScene() {
		var p = this;
		while( p.parent != null ) p = p.parent;
		return Std.instance(p, Scene);
	}
	
	public function addChild( s : Sprite ) {
		//in flash it throw an assert
		if ( s.parent != null) throw "sprite already has a parent";
		addChildAt(s, childs.length);
		s.posChanged = true;
	}
	
	public function addChildAt( s : Sprite, pos : Int ) {
		if( pos < 0 ) pos = 0;
		if( pos > childs.length ) pos = childs.length;
		var p = this;
		while( p != null ) {
			if( p == s ) throw "Recursive addChild";
			p = p.parent;
		}
		if( s.parent != null ) {
			// prevent calling onDelete
			var old = s.allocated;
			s.allocated = false;
			s.parent.removeChild(s);
			s.allocated = old;
		}
		childs.insert(pos, s);
		if( !allocated && s.allocated )
			s.onDelete();
		s.parent = this;
		s.posChanged = true;
		// ensure that proper alloc/delete is done if we change parent
		if( allocated ) {
			if( !s.allocated )
				s.onAlloc();
			else
				s.onParentChanged();
		}
	}
	
	// called when we're allocated already but moved in hierarchy
	function onParentChanged() {
	}
	
	// kept for internal init
	function onAlloc() {
		allocated = true;
		for( c in childs )
			c.onAlloc();
	}
		
	// kept for internal cleanup
	function onDelete() {
		allocated = false;
		for( c in childs )
			c.onDelete();
	}
	
	public function removeChild( s : Sprite ) {
		if( childs.remove(s) ) {
			if( s.allocated ) s.onDelete();
			s.parent = null;
		}
	}
	
	public inline function removeAllChildren() {
		var s = null;
		while( childs.remove(s=childs[0]) ) {
			if( s.allocated ) s.onDelete();
			s.parent = null;
		}
	}
	
	
	
	function draw( ctx : RenderContext ) {
	}
	
	function sync( ctx : RenderContext ) {
		var changed = posChanged;
		if( changed ) {
			calcAbsPos();
			posChanged = false;
		}
		
		lastFrame = ctx.frame;
		var p = 0, len = childs.length;
		while( p < len ) {
			var c = childs[p];
			if( c == null )
				break;
			if( c.lastFrame != ctx.frame ) {
				if( changed ) c.posChanged = true;
				c.sync(ctx);
			}
			// if the object was removed, let's restart again.
			// our lastFrame ensure that no object will get synched twice
			if( childs[p] != c ) {
				p = 0;
				len = childs.length;
			} else
				p++;
		}
	}
	
	function syncPos() {
		if ( !posChanged ) return;
		
		if( parent != null ) parent.syncPos();
		if( posChanged ) {
			calcAbsPos();
			for( c in childs )
				c.posChanged = true;
			posChanged = false;
		}
	}
	
	@:noDebug
	function calcAbsPos() {
		if ( parent == null ) {
			var t = h2d.Tools.getCoreObjects().tmpMatrix2D;
			t.identity();
			
			if ( skewX != 0 || skewY != 0) 		t.skew( skewX, skewY );
			if( scaleX != 0 || scaleY != 0) 	t.scale( scaleX, scaleY);
			if( rotation != 0) 					t.rotate(rotation);
			
			t.translate(x, y );
			
			matA = t.a;
			matB = t.b;
			matC = t.c;
			matD = t.d;
			absX = t.tx;
			absY = t.ty;
			
		} else { 
			
			var t = h2d.Tools.getCoreObjects().tmpMatrix2D;
			t.identity();
			
			if ( skewX != 0 || skewY != 0) 		t.skew( skewX, skewY );
			if ( scaleX != 0 || scaleY != 0) 	t.scale( scaleX, scaleY);
			if ( rotation != 0) 				t.rotate(rotation);
			
			var p = h2d.Tools.getCoreObjects().tmpMatrix2D_2;
			p.identity();
			
			p.a = parent.matA;
			p.b = parent.matB;
			p.c = parent.matC;
			p.d = parent.matD;
			
			t.concat( p );
			
			p.tx = parent.absX;
			p.ty = parent.absY;
			
			matA = t.a;
			matB = t.b;
			matC = t.c;
			matD = t.d;
			
			absX = p.transformX( x , y );
			absY = p.transformY( x , y );
		}
	}
	

	function drawRec( ctx : RenderContext ) {
		if( !visible ) return;
		// fallback in case the object was added during a sync() event and we somehow didn't update it
		if( posChanged ) {
			// only sync anim, don't update() (prevent any event from occuring during draw())
			// if( currentAnimation != null ) currentAnimation.sync();
			calcAbsPos();
			for( c in childs )
				c.posChanged = true;
			posChanged = false;
		}
		draw(ctx);
		for( c in childs )
			c.drawRec(ctx);
	}

	inline function set_x(v) {
		x = v;
		posChanged = true;
		return v;
	}

	inline function set_y(v) {
		y = v;
		posChanged = true;
		return v;
	}
	
	inline function set_scaleX(v) {
		scaleX = v;
		posChanged = true;
		return v;
	}
	
	inline function set_scaleY(v) {
		scaleY = v;
		posChanged = true;
		return v;
	}
	
	inline function set_skewX(v) {
		skewX = v;
		posChanged = true;
		return v;
	}
	
	inline function set_skewY(v) {
		skewY = v;
		posChanged = true;
		return v;
	}
	
	inline function set_rotation(v) {
		rotation = v;
		posChanged = true;
		return v;
	}
	
	/**
	 * Use it to move x y along the rotation direction
	 */
	public function move( dx : hxd.Float32, dy : hxd.Float32 ) {
		x += dx * Math.cos(rotation);
		y += dy * Math.sin(rotation);
	}

	public inline function setPos( x : hxd.Float32, y : hxd.Float32 ) {
		this.x = x;
		this.y = y;
	}
	
	public inline function rotate( v : hxd.Float32 ) {
		rotation += v;
	}
	
	public inline function scale( v : hxd.Float32 ) {
		scaleX *= v;
		scaleY *= v;
	}
	
	public inline function setScale( v : hxd.Float32 ) {
		scaleX = v;
		scaleY = v;
	}

	public inline function getChildAt( n ) {
		return childs[n];
	}

	public function getChildIndex( s ) {
		for( i in 0...childs.length )
			if( childs[i] == s )
				return i;
		return -1;
	}
	
	public inline function toBack( ) 	if( parent != null) parent.setChildIndex( this , 0);
	public inline function toFront()	if( parent != null) parent.setChildIndex( this , parent.numChildren - 1 );
	
	public function setChildIndex(c,idx) {
		if( childs.remove(c) )
			childs.insert(idx, c);
	}
	
	inline function get_numChildren() {
		return childs.length;
	}

	public inline function iterator() {
		return new hxd.impl.ArrayIterator(childs);
	}
	
	public function getChildByName(name:String) {
		for ( c in this ) 
			if (c.name == name ) 
				return c;
		return null;
	}
	
	public function findByName(name:String) {
		if ( this.name == name ) return this;
		
		for ( c in childs )  {
			var s = c.findByName( name );
			if ( s != null ) 
				return s;
		}
		
		return null;
	}
	
	public function set_width(v:Float):Float {
		throw "cannot set width of this object";
		return v;
	}
	
	public function set_height(h:Float):Float {
		throw "cannot set height of this object";
		return h;
	}
	
	public function get_width():Float { 
		return getBounds(parent).width;
	}
	
	public function get_height():Float { 
		return getBounds(parent).height;
	}
	
	#if (flash || openfl)
	/**
	 * This is a dev helper because it will create single textures, see Tile.hx for more powerful functions
	 */
	public static function fromSprite(v:flash.display.DisplayObject,?parent) : h2d.Bitmap{
		return new Bitmap( Tile.fromSprite(v), parent);
	}
	
	public var flashStage(get, null) : flash.display.Stage;
	inline function get_flashStage() return flash.Lib.current.stage;
	
	#end
		
	public inline function get_stage() {
		return hxd.Stage.getInstance();
	}
	
	public function detach() {
		if ( parent == null ) return -1;
		
		var idx = parent.getChildIndex( this );
		parent.removeChild(this);
		return idx;
	}
	
	public inline function remove() {
		if( this != null && parent != null ) parent.removeChild(this);
	}
	
	public function traverse(f) {
		f(this);
		for (c in this)
			c.traverse(f);
	}

	public function dispose() {
		detach();
		
		if( allocated ) onDelete();
		
		removeAllChildren();
	}
	
	function get_mouseX():Float {
		return globalToLocal( new h2d.col.Point( stage.mouseX, stage.mouseY)).x;
	}
	
	function get_mouseY():Float {
		return globalToLocal( new h2d.col.Point( stage.mouseX, stage.mouseY)).y;
	}
	
	
	
}