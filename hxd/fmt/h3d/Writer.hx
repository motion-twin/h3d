package hxd.fmt.h3d;

import h3d.anim.Animation;
import h3d.mat.MeshMaterial;
import h3d.prim.FBXModel;
import h3d.prim.Primitive;
import h3d.scene.Mesh;
import h3d.scene.MultiMaterial;
import h3d.scene.Object;
import h3d.scene.Scene;
import h3d.scene.Skin;
import hxd.fmt.h3d.Data;

using Type;
using hxd.fmt.h3d.Tools;

class Writer {

	var output : haxe.io.Output;
	
	static var MAGIC = "H3D.DATA";
	static var VERSION = 1;
	
	public function new(o : haxe.io.Output) {
		output = o;
	}
	
	public function addGeometry( data:Data, prim : h3d.prim.Primitive ) : Int {
		var fbx = Std.instance(prim, h3d.prim.FBXModel);
		var i = data.geometries.length;
		
		if ( fbx != null) {
			data.geometries.push( GeometryWriter.fromFbx(fbx ));
			return i;
		}
		
		#if debug
		throw "fmt.h3d:unsupported geometry class "+Type.getClass( prim );
		#end
		
		return -1;
	}
	
	public function addAnimation( data:Data, anim: h3d.anim.Animation ) : Int{
		var i = data.animations.length;
		
		#if debug
		trace("adding animation");
		#end
		
		data.animations.push( AnimationWriter.make( anim ) );
		return i;
	}
	
	public function addMaterial( data:Data, mat:h3d.mat.Material ) {
		
		var meshMat = Std.instance(mat, h3d.mat.MeshMaterial);
		var i = data.materials.length;
		
		if ( meshMat != null) {
			data.materials.push( MaterialWriter.make(meshMat) );
			return i;
		}
		
		#if debug
		throw "fmt.h3d:unsupported material class : "+Type.getClass( mat );
		#end
		
		return -1;
	}
	
	public function write( obj : h3d.scene.Object ) {
		writeData(buildLibrary(obj));
	}
	
	public function buildLibrary(obj : h3d.scene.Object, ?data) : Data {
		if ( data == null) data = new Data();
		
		data.root = addModel(data, obj );
		
		#if false
		for( i in 0...data.materials.length)
			trace("material library: #" + i + " name:" + data.materials[i]);
			
		for( i in 0...data.geometries.length)
			trace("geometries library: #" + i + " name:" + data.geometries[i]);
			
		for( i in 0...data.animations.length)
			trace("animations library: #" + i + " name:" + data.animations[i].name);
			
		for( i in 0...data.models.length)
			trace("models library: #" + i + " name:" + data.models[i].name);
		#end
		
		return data;
	}
	
	function addModel( data:Data, o : h3d.scene.Object ) : Int {
		var data = data==null?new Data():data;
		var model = new Model();
		
		model.name = o.name;
		model.pos = new ModelPosition();
		
		model.pos.x = o.x;
		model.pos.y = o.y;
		model.pos.z = o.z;
		
		model.pos.sx = o.scaleX;
		model.pos.sy = o.scaleY;
		model.pos.sz = o.scaleZ;
		
		var vEuler = o.getRotation();
		model.pos.rx = vEuler.x;
		model.pos.ry = vEuler.y;
		model.pos.rz = vEuler.z;
		
		if( null != o.defaultTransform)
			model.defaultTransform = o.defaultTransform.clone();
		
		model.materials = [];
		model.geometries = [];
		model.animations = [];
		model.animations = [];
		model.subModels = [];
		
		var mesh = Std.instance(o, h3d.scene.Mesh);
		if ( mesh != null && mesh.primitive != null ) {
			model.geometries.push( addGeometry(data, mesh.primitive ) );
			model.materials.push( addMaterial(data, mesh.material ) );
			var skin = Std.instance(o, h3d.scene.Skin);
			if ( skin != null) {
				model.skin = SkinWriter.make( skin.skinData );
			}
		}
		
		for ( a in o.animations) 
			model.animations.push( addAnimation( data, a ) );
		
		var i = data.models.length;
		data.models.push( model );
		
		for ( c in o ) 
			model.subModels.push(addModel(data,c));
			
		return i;
	}
	
	function writeTRS(data:hxd.fmt.h3d.Data.ModelPosition) {
		output.writeFloat(data.x);
		output.writeFloat(data.y);
		output.writeFloat(data.z);
		
		output.writeFloat(data.rx);
		output.writeFloat(data.ry);
		output.writeFloat(data.rz);
		
		output.writeFloat(data.sx);
		output.writeFloat(data.sy);
		output.writeFloat(data.sz);
	}
	
	function writeModel( data : Model) {
		output.condWriteString2( data.name);
		writeTRS(data.pos);
		output.writeIndexArray( data.geometries );
		output.writeIndexArray( data.materials );
		output.writeIndexArray( data.subModels );
		output.writeIndexArray( data.animations );
		
		output.writeBool(data.skin != null);
		if( data.skin != null){
			var skw = new hxd.fmt.h3d.SkinWriter(output);
			skw.writeData( data.skin );
		}
		
		output.condWriteMatrix(data.defaultTransform);
		output.writeInt32(0xE0F);
	}
	
	function writeData( data : hxd.fmt.h3d.Data ) {
		
		output.bigEndian = false;
		
		output.writeString(MAGIC);
		output.writeInt32(VERSION);
		
		var byte :haxe.io.BytesOutput = cast output;
		var arr = data.geometries;
		output.writeInt32(arr.length);
		for ( i in 0...arr.length ) 
			new hxd.fmt.h3d.GeometryWriter(output).writeData(arr[i]);
			
		var arr = data.materials;
		output.writeInt32(arr.length);
		for ( i in 0...arr.length ) 
			new hxd.fmt.h3d.MaterialWriter(output).writeData(arr[i]);
			
		var arr = data.animations;
		output.writeInt32(arr.length);
		for ( i in 0...arr.length ) 
			new hxd.fmt.h3d.AnimationWriter(output).writeData(arr[i]);
			
		var arr = data.models;
		output.writeInt32(arr.length);
		for ( i in 0...arr.length ) 
			writeModel( data.models[i] );
		
		output.writeInt32( data.root );
		output.writeInt32( 0xE0F );
	}
	
}