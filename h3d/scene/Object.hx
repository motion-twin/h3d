package h3d.scene;

import haxe.ds.Vector;
import hxd.Profiler;

class Object {

	public
	var childs : Array<Object>;
	public var parent(default, null) : Object;
	public var numChildren(get, never) : Int;
	
	public var name : Null<String>;
	public var visible : Bool = true;
	public var skipOcclusion = true;
	
	public var x(default,set) 		: hxd.Float32;
	public var y(default, set) 		: hxd.Float32;
	public var z(default, set) 		: hxd.Float32;
	public var scaleX(default,set) 	: hxd.Float32;
	public var scaleY(default, set) : hxd.Float32;
	public var scaleZ(default,set) 	: hxd.Float32;
	
	/**
		Follow a given object or joint as if it was our parent. Ignore defaultTransform when set.
	**/
	public var follow(default,set) : Object;

	/**
		This is an additional optional transformation that is performed before other local transformations.
		It is used by the animation system.
	**/
	public var defaultTransform(default, set) : h3d.Matrix;
	
	/**
	 * This is an additional optional transformation that is performed before other local transformations.
	 * It is used before defaultTransform and h3d will not use ot it :)
	 */
	public var customTransform(default, set) : Null<h3d.Matrix>;
	
	public var currentAnimation(get, null) : h3d.anim.Animation;
	
	var absPos : h3d.Matrix;
	var invPos : h3d.Matrix;
	public var qRot : h3d.Quat;
	var posChanged : Bool;
	var lastFrame : Int;
	
	public var animations : Array<h3d.anim.Animation>;
	public var behaviour(default,null) : Null<List< hxd.Behaviour >>;
	
	public function new( ?parent : Object ) {
		absPos = new h3d.Matrix();
		absPos.identity();
		x = 0; y = 0; z = 0; scaleX = 1; scaleY = 1; scaleZ = 1;
		qRot = new h3d.Quat();
		posChanged = false;
		childs = [];
		if( parent != null ) parent.addChild(this);
		animations = [];
	}
	
	public function get_currentAnimation() : h3d.anim.Animation  {
		return animations[0];
	}
	
	public function playAnimation( a : h3d.anim.Animation, slot:Int=0) : h3d.anim.Animation {
		return animations[slot] = a.createInstance(this);
	}
	
	public function addBehaviour(b) {
		if (behaviour == null) behaviour = new List();
		behaviour.push(b);
	}
	
	public function removeBehaviour(b) {
		behaviour.remove(b);
		if ( behaviour.length == 0) behaviour = null;
	}
	
	/**
		Changes the current animation. This animation should be an instance that was created by playAnimation!
	**/
	public function switchToAnimation( a : h3d.anim.Animation , slot:Int = 0) {
		if ( !a.isInstance ) throw "the animation must be bound";
		return animations[slot] = a;
	}
	
	public function stopAnimation( slot:Int=0) {
		animations[slot] = null;
	}
	
	public function getObjectsCount() {
		var k = 0;
		for( c in childs )
			k += c.getObjectsCount() + 1;
		return k;
	}
	
	/**
		Transform a point from the local object coordinates to the global ones. The point is modified and returned.
	**/
	public function localToGlobal( ?pt : h3d.Vector ) {
		syncPos();
		if( pt == null ) pt = new h3d.Vector();
		pt.transform3x4(absPos);
		return pt;
	}

	/**
		Transform a point from the global coordinates to the object local ones. The point is modified and returned.
	**/
	public function globalToLocal( pt : h3d.Vector ) {
		syncPos();
		pt.transform3x4(getInvPos());
		return pt;
	}
	
	function getInvPos() {
		if( invPos == null ) {
			invPos = new h3d.Matrix();
			invPos._44 = 0;
		}
		if( invPos._44 == 0 )
			invPos.inverse3x4(absPos);
		return invPos;
	}

	public function getBounds( ?b : h3d.col.Bounds ) {
		if( b == null ) {
			b = new h3d.col.Bounds();
			syncPos();
		} else if( posChanged ) {
			for( c in childs )
				c.posChanged = true;
			calcAbsPos();
			posChanged = false;
		}
		for( c in childs )
			c.getBounds(b);
		return b;
	}
	
	public function getObjectByName( name : String ) {
		if( this.name == name )
			return this;
		for( c in childs ) {
			var o = c.getObjectByName(name);
			if( o != null ) return o;
		}
		return null;
	}

	/*
	 * Does not clone the parent
	 */
	public function clone( ?o : Object ) : Object {
		if( o == null ) o = new Object();
		o.x = x;
		o.y = y;
		o.z = z;
		o.scaleX = scaleX;
		o.scaleY = scaleY;
		o.scaleZ = scaleZ;
		o.name = name;
		o.qRot = qRot.clone();
		
		if( defaultTransform != null ) 	o.defaultTransform = defaultTransform.clone();
		if( customTransform != null) 	o.customTransform = customTransform.clone();
			
		for( c in childs ) {
			var c = c.clone();
			c.parent = o;
			o.childs.push(c);
		}
		
		for ( i in 0...animations.length ) {
			o.animations[i] = 
				animations[i]==null ?null : animations[i].createInstance(o);
		}
		
		if( behaviour!=null)
			o.behaviour = behaviour.map( function(b) return b.clone(o) );
		
		return o;
	}
	
	public function addChild( o : Object ) {
		addChildAt(o, childs.length);
	}
	
	public function addChildAt( o : Object, pos : Int ) {
		if( pos < 0 ) pos = 0;
		if( pos > childs.length ) pos = childs.length;
		var p = this;
		while( p != null ) {
			if( p == o ) throw "Recursive addChild";
			p = p.parent;
		}
		if( o.parent != null )
			o.parent.removeChild(o);
		childs.insert(pos,o);
		o.parent = this;
		o.lastFrame = -1;
		o.posChanged = true;
	}
	
	public function swapChildren(v0,v1) {
		var idx0 = childs.indexOf(v0);
		var idx1 = childs.indexOf(v1);
		var tmp = childs[idx0];
		childs[idx0] = childs[idx1];
		childs[idx1] = tmp;
	}
	
	public function removeChild( o : Object ) {
		if( childs.remove(o) )
			o.parent = null;
	}
	
	public inline function isMesh() 			return Std.is(this, Mesh);
	
	public function toMesh() : Mesh {
		if( isMesh() ) return cast this;
		throw (name == null ? "Object" : name) + " is not a Mesh";
	}
	
	// shortcut for parent.removeChild
	public inline function remove() {
		if( this != null && parent != null ) parent.removeChild(this);
	}
	
	function draw( ctx : RenderContext ) 
		ctx.localPos = absPos;
	
	function set_follow(v) {
		posChanged = true;
		return follow = v;
	}
	
	public inline function getMatrix() : h3d.Matrix{
		return absPos.clone();
	}
	
	function calcAbsPos() {
		Profiler.begin("Object:calcAbsPos");
		
		qRot.saveToMatrix(absPos);
		// prepend scale
		absPos._11 *= scaleX;
		absPos._12 *= scaleX;
		absPos._13 *= scaleX;
		absPos._21 *= scaleY;
		absPos._22 *= scaleY;
		absPos._23 *= scaleY;
		absPos._31 *= scaleZ;
		absPos._32 *= scaleZ;
		absPos._33 *= scaleZ;
		absPos._41 = x;
		absPos._42 = y;
		absPos._43 = z;
		if( follow != null ) {
			follow.syncPos();
			absPos.multiply3x4(absPos, follow.absPos);
			posChanged = true;
		} else {
			if( defaultTransform != null )
				absPos.multiply3x4(absPos, defaultTransform);
				
			if ( customTransform != null )
				absPos.multiply3x4(absPos, customTransform);
				
			if( parent != null )
				absPos.multiply3x4(absPos, parent.absPos);
		}
		
		if( invPos != null )
			invPos._44 = 0; // mark as invalid
			
		Profiler.end("Object:calcAbsPos");
	}
	
	function sync( ctx : RenderContext ) {
		//if ( currentAnimation != null ) {
		for( ca in animations){
			if ( ca == null) continue;
			
			Profiler.begin("Object:sync.animation");
			
			var old = parent;
			var dt = ctx.elapsedTime;
			while( dt > 0 && ca != null )
				dt = ca.update(dt);
			if( ca != null )
				ca.sync();
				
			Profiler.end("Object:sync.animation");
			
			if( parent == null && old != null ) return; // if we were removed by an animation event
		}
		
		var changed = posChanged;
		if( changed ) {
			posChanged = false;
			calcAbsPos();
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
		
		if ( behaviour != null) for (b in behaviour) b.update();
	}
	
	function syncPos() {
		if( parent != null ) parent.syncPos();
		if( posChanged ) {
			calcAbsPos();
			for( c in childs )
				c.posChanged = true;
			posChanged = false;
		}
	}
	
	inline
	function isOccluded( ctx : RenderContext ) {
		if ( skipOcclusion ) return false;
		return !getBounds().inFrustum(ctx.camera.m);
	}
	
	function drawRec( ctx : RenderContext ) {
		if ( !visible ) return;
		if ( isOccluded(ctx) ) return;
			
		// fallback in case the object was added during a sync() event and we somehow didn't update it
		if( posChanged ) {
			// only sync anim, don't update() (prevent any event from occuring during draw())
			for( ca in animations) if(ca!=null) ca.sync();
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

	inline function set_z(v) {
		z = v;
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

	inline function set_scaleZ(v) {
		scaleZ = v;
		posChanged = true;
		return v;
	}
	
	inline function set_defaultTransform(v) {
		defaultTransform = v;
		posChanged = true;
		return v;
	}
	
	inline function set_customTransform(v) {
		customTransform = v;
		posChanged = true;
		return v;
	}
	
	/*
		Move along the current rotation axis
	*/
	public inline function move( dx : Float, dy : Float, dz : Float ) {
		x += dx;
		y += dy;
		z += dz;
		posChanged = true;
	}

	public inline function setPos( x : Float, y : Float, z : Float ) {
		this.x = x;
		this.y = y;
		this.z = z;
		posChanged = true;
	}
	
	/*
		Rotate around the current rotation axis.
	*/
	public inline function rotate( rx : Float, ry : Float, rz : Float ) {
		var qTmp = new h3d.Quat();
		qTmp.initRotate(rx, ry, rz);
		qRot.add(qTmp);
		posChanged = true;
	}
	
	/**
	 * Sets the rotation in a TRxRyRzS fashion
	 * which means we apply a rotation from angle 0 then ax around x axis then ay around y axis then ax around z axis
	 * TODO DE : rename to more canonical setRotation(ax,ay,az)
	 */
	public inline function setRotate( rx : Float, ry : Float, rz : Float ) {
		qRot.initRotate(rx, ry, rz);
		posChanged = true;
	}
	
	public inline function setRotateAxis( ax : Float, ay : Float, az : Float, angle : Float ) {
		qRot.initRotateAxis(ax, ay, az, angle);
		posChanged = true;
	}
	
	public inline function getRotation() : h3d.Vector {
		return qRot.toEuler();
	}
	
	public inline function getRotationQuat() {
		return qRot;
	}
	
	public inline function setRotationQuat(q) {
		qRot = q;
		posChanged = true;
	}
	
	public inline function scale( v : Float ) {
		scaleX *= v;
		scaleY *= v;
		scaleZ *= v;
		posChanged = true;
	}
	
	public inline function setScale( v : Float ) {
		scaleX = v;
		scaleY = v;
		scaleZ = v;
		posChanged = true;
	}
	
	public function toString() {
		return Type.getClassName(Type.getClass(this)).split(".").pop() + (name == null ? "" : "(" + name + ")");
	}
	
	public inline function getChildAt( n ) 								return childs[n];
	public inline function getChildIndex( o ) 							return childs.indexOf( o );
	public inline function iterator() : hxd.impl.ArrayIterator<Object> 	return new hxd.impl.ArrayIterator(childs);
	
	inline function get_numChildren() 									return childs.length;
	
	public function dispose() {
		remove();
		
		if(behaviour != null)
			for ( b in behaviour ) b.dispose();
			
		for( c in childs ) c.dispose();
	}
	
	public function removeAllChildren() {
		while ( childs.length != 0 ) 
			childs.pop();
	}
	
	public function traverse(f) {
		f(this);
		for ( c in childs )
			c.traverse(f);
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
	
	public inline function getPos(?out:h3d.Vector):h3d.Vector {
		var out = out!=null?out:new h3d.Vector();
		out.set(x, y, z, 1.0);
		return out;
	}
}
