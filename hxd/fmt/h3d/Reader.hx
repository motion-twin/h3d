package hxd.fmt.h3d;

import hxd.fmt.h3d.Data;

using Type;
using hxd.fmt.h3d.Tools;

class Reader {
	
	var input : haxe.io.Input;
	var tl : String->Void;
	
	static var MAGIC = "H3D.DATA";
	static var VERSION = 1;
	
	public function new(o : haxe.io.Input) {
		input = o;
	}
	
	//////////////////////////////////////////////
	public var root 		: h3d.scene.Object;
	public var geometries 	: haxe.ds.Vector<h3d.prim.Primitive>;
	public var materials 	: haxe.ds.Vector<h3d.mat.Material>;
	public var animations 	: haxe.ds.Vector<h3d.anim.Animation>;
	public var models 		: haxe.ds.Vector<h3d.scene.Object>;
	
	public function read() : hxd.fmt.h3d.Library {
		return makeLibrary( readData() );
	}
	
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
		
		root = (l.root = models[o.root]);
		
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
			node = new h3d.scene.MultiMaterial( geom(m.geometries[0]), mats );
		}
		//skinned
		else if ( m.skin != null) {
			
			var g = fbxModel(0);
			var sk : h3d.anim.Skin = SkinReader.make(m.skin);
			g.skin = sk;
			sk.primitive = g;
			
			node = new h3d.scene.Skin( sk, meshMat(m.materials[0]) );
		}
		//simple geometries
		else if( m.geometries.length > 0 )
			node = new h3d.scene.Mesh( geom(m.geometries[0]) , meshMat(m.materials[0]));
		//dummies
		else 
			node = new h3d.scene.Object();
			
		node.name = m.name;
		
		node.setPos( m.pos.x,m.pos.y,m.pos.z );
		node.setRotate( m.pos.rx, m.pos.ry, m.pos.rz );
		
		node.scaleX = m.pos.sx;
		node.scaleY = m.pos.sy;
		node.scaleZ = m.pos.sz;
		
		if ( m.defaultTransform != null)
			node.defaultTransform = m.defaultTransform.clone();
		
		return node;
	}
	
	function linkModel( obj : h3d.scene.Object, m : Model ) : h3d.scene.Object {
		if( m.subModels!=null )
		for ( subId in m.subModels ) {
			var o = model(subId);
			obj.addChild( o );
			hxd.System.trace1("added sub " + o.name+" to:"+obj.name);
		}
			
		if( null != m.animations)
		for ( a in m.animations ) {
			trace(	"reading animation on " + obj.name );
			obj.playAnimation( anim(a), obj.animations.length );
		}
			
		hxd.System.trace1("read " + obj.name);
		if ( obj.parent != null ) 
			hxd.System.trace1("parent is :" + obj.parent.name);
			
		return obj;
	}
	
	public function readData() : hxd.fmt.h3d.Data {
		var data = new Data();
		
		input.bigEndian = false;
		
		var s = input.readString( MAGIC.length );	if ( s != MAGIC ) throw "invalid " + MAGIC + " magic";
		var version = input.readInt32(); 			if ( version != VERSION ) throw "invalid .h3d. version "+VERSION;
		
		var byte :haxe.io.BytesInput = cast input;
		trace("start:" + byte.position);
		
		var arrLen = input.readInt32();
		for ( i in 0...arrLen )
			data.geometries.push(new hxd.fmt.h3d.GeometryReader(input).parse());
			
		trace("geom:" + byte.position);
		
		var arrLen = input.readInt32();
		for ( i in 0...arrLen )
			data.materials.push(new hxd.fmt.h3d.MaterialReader(input).parse());
			
		trace("mat:" + byte.position);
			
		var arrLen = input.readInt32();
		for ( i in 0...arrLen )
			data.animations.push(new hxd.fmt.h3d.AnimationReader(input).parse());
			
		trace("anim:" + byte.position+" nb:"+arrLen);
			
		var arrLen = input.readInt32();
		for ( i in 0...arrLen )
			data.models.push(readModel());
			
		trace("model:" + byte.position);
			
		data.root = input.readInt32();
		
		if ( input.readInt32() != 0xE0F ) throw "assert : file was not correctly parsed!";
		
		return data;
	}
	
	function readTRS(data:hxd.fmt.h3d.Data.ModelPosition) {
		data.x	= input.readFloat();
		data.y	= input.readFloat();
		data.z	= input.readFloat();
                        
		data.rx	= input.readFloat();
		data.ry	= input.readFloat();
		data.rz	= input.readFloat();
                        
		data.sx	= input.readFloat();
		data.sy	= input.readFloat();
		data.sz	= input.readFloat();
		return data;
	}
	
	function readModel() : hxd.fmt.h3d.Data.Model {
		var data 	= new hxd.fmt.h3d.Data.Model();
		
		data.name 	= input.condReadString2();
		data.pos 	= readTRS(new ModelPosition());
		
		data.geometries = input.readIndexArray();
		data.materials = input.readIndexArray();
		data.subModels = input.readIndexArray();
		data.animations = input.readIndexArray();
		
		if ( input.readBool() ) 
			data.skin = new hxd.fmt.h3d.SkinReader(input).parse();
			
		data.defaultTransform = input.condReadMatrix();
		
		if ( input.readInt32() != 0xE0F ) throw "assert : file was not correctly parsed!";
		
		return data;
	}
}
