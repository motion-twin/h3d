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
		throw "fmt.h3d:unsupported geometry class"+Type.getClass( prim );
		#end
		
		return -1;
	}
	
	public function addAnimation( data:Data, mat: h3d.anim.Animation ) : Int{
		var i = data.animations.length;
		data.animations.push( AnimationWriter.make( mat ) );
		return i;
	}
	
	public function addMaterial( data:Data, mat:h3d.mat.Material ) {
		var meshMat = Std.instance(mat, h3d.mat.MeshMaterial);
		var i = data.geometries.length;
		
		if ( mat != null) {
			data.materials.push( MaterialWriter.make(meshMat) );
			return i;
		}
		
		#if debug
		throw "fmt.h3d:unsupported material class : "+Type.getClass( mat );
		#end
		
		return -1;
	}
	
	public function add(obj : h3d.scene.Object, ?data) : Data {
		if ( data == null) data = new Data();
		
		addModel(data, obj );
		
		return data;
	}
	
	function addModel( data:Data, o : h3d.scene.Object ) : Int {
		var data = data==null?new Data():data;
		
		var model = new Model();
		
		model.name = o.name;
		model.defaultTransform = o.defaultTransform.clone();
		
		var mesh = Std.instance(o, h3d.scene.Mesh);
		if ( mesh != null) {
			
			if (model.geometries == null) model.geometries = [];
			model.geometries.push( addGeometry(data, mesh.primitive ) );
			
			if (model.materials == null) model.materials = [];
			model.materials.push( addMaterial(data, mesh.material ) );
			
			var skin = Std.instance(o, h3d.scene.Skin);
			if ( skin != null) 
				model.skin = SkinWriter.make( skin.skinData );
		}
		
		for ( a in o.animations) {
			if ( model.animations == null) model.animations = [];
			model.animations.push( addAnimation( data, a ) );
		}
			
		for ( c in o ) {
			if ( model.subModels == null) model.subModels = [];
			model.subModels.push(addModel(data,c));
		}
			
		var i = data.models.length;
		data.models.push( model );
		return i;
	}
	
}