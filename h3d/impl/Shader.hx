package h3d.impl;


#if macro
import haxe.macro.Context;
import haxe.macro.Type.Ref;
#end

#if flash
typedef Shader = hxsl.Shader;
#elseif (js || cpp)

typedef ShaderLocation = #if js js.html.webgl.UniformLocation #else openfl.gl.GLUniformLocation #end;
enum ShaderType {
	Float;
	Vec2;
	Vec3;
	Vec4;
	Mat2;
	Mat3;
	Mat4;
	Tex2d;
	TexCube;
	Byte3;
	Byte4;
	Struct( field : String, t : ShaderType );
	Index( index : Int, t : ShaderType );
	Elements( field : String, size:Null<Int>, t : ShaderType);//null means size in indefinite and will be context relative
}

@:publicFields
class Uniform { 
	var name : String;
	var loc : ShaderLocation;
	var type : ShaderType;
	var index : Int;
	
	inline function new(n:String,l:ShaderLocation,t:ShaderType,i) {
		name = n;
		loc = l;
		type = t;
		index = i;
	}
}

@:publicFields
class Attribute {
	var etype : Int;
	var offset : Int; 
	var index : Int;
	var size : Int;
	
	var name : String;
	var type : ShaderType;
	
	function new(n:String,t:ShaderType,e,o,i,s) {
		name = n;
		type = t;
		etype = e;
		offset = o;
		index = i;
		size = s;
	}
	
	public function toString() {
		return 'etype:$etype offset::$offset index:$index size:$size name:$name type:$type';
	}
}

class ShaderInstance {

	public var program : #if js js.html.webgl.Program #else openfl.gl.GLProgram #end;
	public var attribs : Array<Attribute>;
	public var attribsNames : Array<String>;
	public var uniforms : Array<Uniform>;
	public var stride : Int;
	public var contextId : Int = -1;
	public var sig : Int;

	public inline function new() { }

}

@:autoBuild(h3d.impl.Shader.ShaderMacros.buildGLShader())
@:allow(h3d.impl.GlDriver)
class Shader {
	
	var instance : ShaderInstance;
	
	public function new() {
	}
	
	function customSetup( driver : h3d.impl.GlDriver ) {
	}
	
	function getConstants( vertex : Bool ) {
		return "";
	}
	
	public inline function invalidate() {
		#if debug
		hxd.System.trace1("shader invalidation !" /*+ haxe.CallStack.callStack()*/);
		#end
		instance = null;
	}

	public function hasInstance() {
		return instance != null;
	}
	
	public function getSignature() {
		return instance==null ? -1 : instance.sig;
	}
}

#else

class Shader implements Dynamic {
	public function new() {
	}
	
	public function hasInstance() {
		return this.instance != null;
	}
	
	public inline function invalidate() {
		//already taken care of
	}
}

#end

#if macro
class ShaderMacros {
	
	public static function buildGLShader() {
		var pos = Context.getLocalClass().get().pos;
		var fields = Context.getBuildFields();
		var hasVertex = false, hasFragment = false;
		var r_uni = ~/uniform[ \t]+((lowp|mediump|highp)[ \t]+)?([A-Za-z0-9_]+)[ \t]+([A-Za-z0-9_]+)[ \t]*(\/\*([A-Za-z0-9_]+)\*\/)?/;
		
		var cl = Std.string(Context.getLocalClass());
		
		function classHasField( c : haxe.macro.Type.Ref< haxe.macro.Type.ClassType> , name)
		{
			if ( c == null ) return false;
			var o = c.get();
			
			return
			if ( o.fields!=null && Lambda.exists( o.fields.get() , function(o) return o.name == name ))
				true;
			else if ( o.superClass == null ) false;
			else classHasField( o.superClass.t , name);
		}
		
		function addUniforms( code : String ) {
			while( r_uni.match(code) ) {
				var name = r_uni.matched(4);
				var type = r_uni.matched(3);
				var hint = r_uni.matched(6);
				code = r_uni.matchedRight();
				var t = switch( type ) {
				case "float": macro : Float;
				case "vec4", "vec3" if( hint == "byte4" ): macro : Int;
				case "vec2", "vec3", "vec4": macro : h3d.Vector;
				case "mat3", "mat4": macro : h3d.Matrix;
				case "sampler2D", "samplerCube": macro : h3d.mat.Texture;
				default:
					// most likely a struct, handle it manually
					if( type.charCodeAt(0) >= 'A'.code && type.charCodeAt(0) <= 'Z'.code )
						continue;
					throw "Unsupported type " + type;
				}
								
				if ( code.charCodeAt(0) == '['.code ) t = macro : Array<$t>;
				if ( classHasField( Context.getLocalClass(), name ) )  continue;
				
				fields.push( {
						name : name,
						kind : FVar(t),
						pos : pos,
						access : [APublic],
						meta:[{name:":keep",params:[],pos:pos}]
					});
			}
		}
		for( f in fields )
			switch( [f.name, f.kind] ) {
				case ["VERTEX", FVar(_,{ expr : EConst(CString(code)) }) ]:
					hasVertex = true;
					addUniforms(code);
				case ["FRAGMENT", FVar(_,{ expr : EConst(CString(code)) })]:
					hasFragment = true;
					addUniforms(code);
				default:
			}
		if( !hasVertex )
			haxe.macro.Context.error("Missing VERTEX shader", pos);
		if( !hasFragment )
			haxe.macro.Context.error("Missing FRAGMENT shader", pos);
			
		return fields;
	}
	
}
#end
