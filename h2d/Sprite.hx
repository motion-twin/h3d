package h2d;

import flash.display.Stage;
import flash.Lib;
import h2d.col.Bounds;
import h2d.col.Circle;
import h2d.col.Point;

import hxd.Math;


@:allow(h2d.Tools)
class Sprite {

	public var name:String;
	var childs : Array<Sprite>;
	public var parent(default, null) : Sprite;
	public var numChildren(get, never) : Int;
	
	public var x(default,set) : Float;
	public var y(default, set) : Float;
	public var scaleX(default,set) : Float;
	public var scaleY(default, set) : Float;
	
	/**
	 * In radians
	 */
	public var rotation(default, set) : Float;
	public var visible : Bool;

	public var matA(default,null) : Float;
	public var matB(default,null): Float;
	public var matC(default,null): Float;
	public var matD(default,null): Float;
	public var absX(default,null): Float;
	public var absY(default,null): Float;
	
	var posChanged(default,set) : Bool;
	var allocated : Bool;
	var lastFrame : Int;
	
	public var pixSpaceMatrix(default,null):Matrix;
	public var  mouseX(get, null) : Float;
	public var  mouseY(get, null) : Float;
	/**
	 * retrieving this is costy because parenthood might need caching and a tranforms will have to be compoted according to content
	 * on some object the setter will just explode at your face
	 */
	@:isVar
	public var width(get, set) : Float;
	
	/**
	 * retrieving this is costy because parenthood might need caching and a tranforms will have to be compoted according to content
	 * on some object the setter will just explode at your face
	 */
	@:isVar
	public var height(get, set) : Float;
	
	public var stage(get,null) : hxd.Stage;
	
	public function new( ?parent : Sprite ) {
		matA = 1; matB = 0; matC = 0; matD = 1; absX = 0; absY = 0;
		x = 0; y = 0; scaleX = 1; scaleY = 1; rotation = 0;
		pixSpaceMatrix = new Matrix();
		posChanged = true;
		visible = true;
		childs = [];
		if( parent != null )
			parent.addChild(this);
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
		var invDet = 1 / (matA * matD - matB * matC);
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
		addChildAt(s, childs.length);
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
	
	// shortcut for parent.removeChild
	public inline function remove() {
		if( this != null && parent != null ) parent.removeChild(this);
	}
	
	function draw( ctx : RenderContext ) {
	}
	
	public function cachePixSpaceMatrix() {
		getPixSpaceMatrix( pixSpaceMatrix );
	}
	
	function sync( ctx : RenderContext ) {
		var changed = posChanged;
		if( changed ) {
			calcAbsPos();
			cachePixSpaceMatrix();
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
			cachePixSpaceMatrix();
			for( c in childs )
				c.posChanged = true;
			posChanged = false;
		}
	}
	
	function getPixSpaceMatrix(?m:Matrix,?tile:Tile) : Matrix{
		if ( m == null ) m = new Matrix();
		else m.identity();
		
		var ax = 0.0;
		var ay = 0.0;
		if ( parent == null || parent == getScene() ) {
			var cr, sr;
			if( rotation == 0 ) {
				cr = 1.; sr = 0.;
				m.a = scaleX;
				m.b = 0;
				m.c = 0;
				m.d = scaleY;
			} else {
				cr = Math.cos(rotation);
				sr = Math.sin(rotation);
				m.a = scaleX * cr;
				m.b = scaleX * -sr;
				m.c = scaleY * sr;
				m.d = scaleY * cr;
			}
			ax = x;
			ay = y;
		} else { 
			parent.syncPos();
			var pm = parent.pixSpaceMatrix;
			
			if( rotation == 0 ) {
				m.a = scaleX * pm.a;
				m.b = scaleX * pm.b;
				m.c = scaleY * pm.c;
				m.d = scaleY * pm.d;
			} else {
				var cr = Math.cos(rotation);
				var sr = Math.sin(rotation);
				
				var tmpA = scaleX * cr;
				var tmpB = scaleX * -sr;
				var tmpC = scaleY * sr;
				var tmpD = scaleY * cr;
				
				m.a = tmpA * pm.a + tmpB * pm.c;
				m.b = tmpA * pm.b + tmpB * pm.d;
				m.c = tmpC * pm.a + tmpD * pm.c;
				m.d = tmpC * pm.b + tmpD * pm.d;
			}
			
			ax = x * pm.a + y * pm.c + pm.tx;
			ay = x * pm.b + y * pm.d + pm.ty;
		}
		
		if( tile != null){
			m.tx = ax + tile.dx * m.a + tile.dy * m.c;
			m.ty = ay + tile.dx * m.b + tile.dy * m.d;
		}
		else {
			m.tx = ax;
			m.ty = ay;
		}
		return m;
	}
	
	function calcAbsPos() {
		if ( parent == null ) {
			//trace("no parent");
			var cr, sr;
			if( rotation == 0 ) {
				cr = 1.; sr = 0.;
				matA = scaleX;
				matB = 0;
				matC = 0;
				matD = scaleY;
			} else {
				cr = Math.cos(rotation);
				sr = Math.sin(rotation);
				matA = scaleX * cr;
				matB = scaleX * -sr;
				matC = scaleY * sr;
				matD = scaleY * cr;
			}
			absX = x;
			absY = y;
		} else { 
			//trace("I have parent " );
			// M(rel) = S . R . T
			// M(abs) = M(rel) . P(abs)
			if( rotation == 0 ) {
				matA = scaleX * parent.matA;
				matB = scaleX * parent.matB;
				matC = scaleY * parent.matC;
				matD = scaleY * parent.matD;
			} else {
				var cr = Math.cos(rotation);
				var sr = Math.sin(rotation);
				var tmpA = scaleX * cr;
				var tmpB = scaleX * -sr;
				var tmpC = scaleY * sr;
				var tmpD = scaleY * cr;
				matA = tmpA * parent.matA + tmpB * parent.matC;
				matB = tmpA * parent.matB + tmpB * parent.matD;
				matC = tmpC * parent.matA + tmpD * parent.matC;
				matD = tmpC * parent.matB + tmpD * parent.matD;
			}
			absX = x * parent.matA + y * parent.matC + parent.absX;
			absY = x * parent.matB + y * parent.matD + parent.absY;
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
	
	inline function set_rotation(v) {
		rotation = v;
		posChanged = true;
		return v;
	}
	
	/**
	 * Use it to move x y along the rotation direction
	 */
	public function move( dx : Float, dy : Float ) {
		x += dx * Math.cos(rotation);
		y += dy * Math.sin(rotation);
	}

	public inline function setPos( x : Float, y : Float ) {
		this.x = x;
		this.y = y;
	}
	
	public inline function rotate( v : Float ) {
		rotation += v;
	}
	
	public inline function scale( v : Float ) {
		scaleX *= v;
		scaleY *= v;
	}
	
	public inline function setScale( v : Float ) {
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
		childs.remove(c);
		childs.insert(idx, c);
	}
	
	inline function get_numChildren() {
		return childs.length;
	}

	public inline function iterator() {
		return new hxd.impl.ArrayIterator(childs);
	}

	function getMyBounds() : Bounds {
		return null;
	}
	
	function getChildrenBounds() : Array<Bounds> {
		return childs.map( function(c) return c.getBounds());
	}
	
	public function set_width(v) {
		throw "cannot set width of this object";
		return v;
	}
	
	public function set_height(h) {
		throw "cannot set height of this object";
		return h;
	}
	
	public function get_width() {
		return getBounds().width;
	}
	
	public function get_height() {
		return getBounds().height;
	}
	
	/**
	 * This functions will cost you an arm.
	 */
	public function getBounds() : Bounds {
		//calcScreenPos();
		
		var cs = getChildrenBounds();
		var res = getMyBounds();
		if ( res == null ) res = cs[0];
		
		if ( res == null && childs.length <= 0 ) {
			var p = localToGlobal();
			return Bounds.fromPoints(p, p);
		}
			
		for ( nr in cs ) 
			res.add( nr );
			
		calcAbsPos();
		return res;
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
		var idx = parent.getChildIndex( this );
		parent.removeChild(this);
		return idx;
	}

	
	function get_mouseX():Float
	{
		var b = getBounds();
		return stage.mouseX - b.xMin;
	}
	
	function get_mouseY():Float 
	{
		var b = getBounds();
		return stage.mouseY - b.yMin;
	}
	
}