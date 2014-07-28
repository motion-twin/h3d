package h2d;

import h2d.col.Bounds;
import h2d.col.Circle;
import h2d.col.Point;

import hxd.Math;

@:allow(h2d.Tools)
@:allow(h2d.Drawable)
class Sprite {

	public var name:String;
	var childs : Array<Sprite>;
	public var parent(default, null) : Sprite;
	public var numChildren(get, never) : Int;
	
	public var x(default,set) : Float;
	public var y(default, set) : Float;
	
	public var scaleX(default,set) : Float = 1.0;
	public var scaleY(default, set) : Float = 1.0;
	
	public var skewX(default,set) : Float = 0.0;
	public var skewY(default, set) : Float = 0.0;
	
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
	
	public var 	pixSpaceMatrix(default,null):Matrix;
	public var  mouseX(get, null) : Float;
	public var  mouseY(get, null) : Float;
	
	#if alpha_inherit
	@:isVar
	public var 	alpha(get,set) : Float;
	#end
	
	/**
	 * COSTS AN ARM
	 * retrieving this is costy because parenthood might need caching and a tranforms will have to be compoted according to content
	 * on some object the setter will just explode at your face
	 */
	@:isVar
	public var width(get, set) : Float;
	
	/**
	 * COSTS AN ARM
	 * retrieving this is costy because parenthood might need caching and a tranforms will have to be compoted according to content
	 * on some object the setter will just explode at your face
	 */
	@:isVar
	public var height(get, set) : Float;
	
	public var stage(get, null) : hxd.Stage;
	
	public function new( ?parent : Sprite ) {
		matA = 1; matB = 0; matC = 0; matD = 1; absX = 0; absY = 0;
		x = 0; y = 0; scaleX = 1; scaleY = 1; rotation = 0;
		skewX = 0; skewY = 0;
		
		pixSpaceMatrix = new Matrix();
		posChanged = true;
		visible = true;
		childs = [];
		if( parent != null )
			parent.addChild(this);
	}
	
	#if alpha_inherit
	function getAlphaRec() {
		if ( parent == null ) 	return alpha;
		else 					return alpha * parent.alpha;		
	}
	
	public function get_alpha() {
		return alpha;
	}
	
	public function set_alpha(v) {
		return alpha=v;
	}
	#end
	
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
		//in flash it throw an assert
		if ( s.parent != null) throw "sprite already has a parent";
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
	
	@:noDebug
	function getPixSpaceMatrix(?m:Matrix,?tile:Tile, ?inherit=true) : Matrix{
		if ( m == null ) m = new Matrix();
		else m.identity();
		
		var ax = 0.0;
		var ay = 0.0;
		if ( parent == null || parent == getScene() || !inherit) {
			
			if ( skewX != 0 || skewY != 0) 		m.skew( skewX, skewY );
			if( scaleX != 0 || scaleY != 0) 	m.scale( scaleX, scaleY);
			if( rotation != 0) 					m.rotate(rotation);
			
			ax = x;
			ay = y;
			
		} else { 
			parent.syncPos();
			var pm = parent.pixSpaceMatrix;
			
			m.identity();
			
			if ( skewX != 0 || skewY != 0) 		m.skew( skewX, skewY );
			if( scaleX != 0 || scaleY != 0) 	m.scale( scaleX, scaleY);
			if( rotation != 0) 					m.rotate(rotation);
			
			m.concat22( pm );
			
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
	
	/**
	 * Returns bound of self content not taking children into account
	 */
	public function getMyBounds(inherit=true) : Bounds {
		return new Bounds();
	}
	
	inline function getChildrenBounds() : Array<Bounds> {
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
		var b = getMyBounds(false);//get my own bounds
		for ( c in getChildrenBounds()){
			if ( b == null) b = new Bounds();
			b.add(c);
		}
			
		if ( b == null)
			return 0.0;
		else 
			return b.width;
	}
	
	public function get_height() { 
		var b = getMyBounds(false);//get my own bounds
		for ( c in getChildrenBounds()){
			if ( b == null) b = new Bounds();
			b.add(c);
		}
			
		if ( b == null)
			return 0.0;
		else 
			return b.height;
	}
	
	/**
	 * This functions will cost you an arm.
	 */
	public function getBounds() : Null<Bounds> {
		
		var res = getMyBounds();
		
		var cs = null;
		if( childs.length>0)
			cs = getChildrenBounds();
			
		if ( res == null && cs != null ) res = cs[0].clone();
		
		if ( res == null && childs.length <= 0 ) {
			var p = localToGlobal();
			return Bounds.fromPoints(p, p);
		}
			
		if ( cs != null && cs.length > 0) {
			//cannot use source as it will be modified
			res = res.clone();
			for ( nr in cs ) {
				if ( nr == null ) 
					throw "assert";
				res.add( nr );
			}
		}
			
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
		if ( parent == null ) return -1;
		
		var idx = parent.getChildIndex( this );
		parent.removeChild(this);
		return idx;
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