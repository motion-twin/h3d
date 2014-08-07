package hxd.fmt.h3d;

import hxd.fmt.h3d.Data;

class Reader {
	
	var input : haxe.io.Input;
	
	static var MAGIC = "H3D.DATA";
	static var VERSION = 1;
	
	public function new(o : haxe.io.Input) {
		input = o;
	}
	
	//////////////////////////////////////////////
	public var geometries : haxe.ds.Vector<h3d.prim.Primitive>;
	public var materials : haxe.ds.Vector<h3d.mat.Material>;
	public var animations : haxe.ds.Vector<h3d.anim.Animation>;
	public var models : haxe.ds.Vector<h3d.scene.Object>;
	
	public function makeLibrary( o : hxd.fmt.h3d.Data ) {
		var l = new Library();
		
		geometries = (l.geometries = new haxe.ds.Vector(o.geometries.length));
		materials = (l.materials = new haxe.ds.Vector(o.materials.length));
		animations = (l.animations = new haxe.ds.Vector(o.animations.length));
		models = (l.models = new haxe.ds.Vector(o.models.length));
		
		for ( i in 0...o.geometries.length ) 
			geometries[i] = GeometryReader.make(o.geometries[i]);
			
		for ( i in 0...o.materials.length ) 
			materials[i] = MaterialReader.make(o.materials[i]);
			
		for ( i in 0...o.animations.length ) 
			animations[i] = AnimationReader.make(o.animations[i]);
			
		for ( i in 0...o.models.length ) 
			models[i] = parseModel( o.models[i] );
		
		for ( i in 0...o.models.length ) 
			models[i] = linkModel( models[i], o.models[i] );
		
		return l;
	}
	
	inline function geom(n) 	return geometries.get(n);
	inline function mat(n) 		return materials.get(n);
	inline function anim(n) 	return animations.get(n);
	inline function model(n) 	return models.get(n);
	
	function meshMat(n) : h3d.mat.MeshMaterial{
 		var mat = materials.get(n);
		if ( !Std.is( mat,h3d.mat.MeshMaterial)){
			throw "MeshMat expected";
			return null;
		}
		else 
			return cast mat;
	}
	
	function fbxModel(n) : h3d.prim.FBXModel{
 		var g = geometries.get(n);
		if ( g==null || !Std.is( g,h3d.prim.FBXModel) ){
			throw "FBXModel expected";
			return null;
		}
		else 
			return cast g;
	}
	
	function parseModel( m : Model ) : h3d.scene.Object {
		var node : h3d.scene.Object;
		function notNull(o) if ( o == null ) throw "unexpected null" else return o;
		
		//multi materials
		if ( m.materials.length > 1) {
			if ( m.geometries.length > 0 ) throw "unsupported scene object type";
			
			var mats : Array<h3d.mat.MeshMaterial>= [];
			for ( m in m.materials ) 
				mats.push(Std.instance(mat(m), h3d.mat.MeshMaterial));
			node = new h3d.scene.MultiMaterial( geom(0), mats );
		}
		//skinned
		else if ( m.skin != null) {
			var g = fbxModel(0);
			var sk : h3d.anim.Skin = SkinReader.make(m.skin);
			g.skin = sk;
			sk.primitive = g;
			node = new h3d.scene.Skin( sk, meshMat(0) );
		}
		//simple geometries
		else if( m.geometries.length > 0 )
			node = new h3d.scene.Mesh( geom(0) , meshMat(0));
		//dummies
		else 
			node = new h3d.scene.Object();
		
		node.name = m.name;
		
		node.setPos( m.pos.x,m.pos.y,m.pos.z );
		node.setRotate( m.pos.rx, m.pos.ry, m.pos.rz );
		node.scaleX = m.pos.sx;
		node.scaleY = m.pos.sy;
		node.scaleZ = m.pos.sz;
		
		if( null != m.animations)
		for ( a in m.animations )
			node.animations.push(anim(a));
		
		return node;
	}
	
	function linkModel( obj : h3d.scene.Object, m : Model ) : h3d.scene.Object {
		if( m.subModels!=null )
		for ( subId in m.subModels )
			obj.addChild( model(subId));
		return obj;
	}
}
