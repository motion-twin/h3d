package h3d.fbx;

enum FbxProp {
	PInt( v : Int );
	PFloat( v : Float );
	PString( v : String );
	PIdent( i : String );
	PInts( v : Array<Int> );
	PFloats( v : Array<Float> );
}

@:publicFields
class FbxNode {
	var name : String;
	var props : Array<FbxProp>;
	var childs : Array<FbxNode>;
	
	/**
	 * 
	 * @param	n is tree name (not necessarily scene name)
	 * @param	p is property 
	 * @param	c is child list
	 */
	@:noDebug
	public inline function new(n,p,c) {
		name = n;
		props = p;
		childs = c;
	}
	
	public inline function toString() {
		return 'name:$name \n props:$props \n childs:$childs';
	}
	
	@:noDebug
	public function get( path : String, opt = false ) {
		var parts = path.split(".");
		var cur = this;
		for( p in parts ) {
			var found = false;
			for( c in cur.childs )
				if( c.name == p ) {
					cur = c;
					found = true;
					break;
				}
			if( !found ) {
				if( opt )
					return null;
				throw name + " does not have " + path+" ("+p+" not found)";
			}
		}
		return cur;
	}

	@:noDebug
	public function getAll( path : String ) {
		var parts = path.split(".");
		var cur = [this];
		for( p in parts ) {
			var out = [];
			for( n in cur )
				for( c in n.childs )
					if( c.name == p )
						out.push(c);
			cur = out;
			if( cur.length == 0 )
				return cur;
		}
		return cur;
	}
	
	@:noDebug
	public function getInts( ) {
		if( props.length != 1 )
			throw name + " has " + props + " props";
		switch( props[0] ) {
		case PInts(v):
			return v;
		default:
			throw name + " has " + props + " props";
		}
	}

	@:noDebug
	public function getFloats() :Array<Float>{
		if( props.length != 1 )
			throw name + " has " + props + " props";
		switch( props[0] ) {
		case PFloats(v):
			return v;
		case PInts(i):
			var fl = new Array<Float>();
			for( x in i )
				fl.push(x);
			return fl;
		default:
			throw name + " has " + props + " props";
		}
	}
	
	@:noDebug
	public function hasProp( p : FbxProp ) {
		for( p2 in props )
			if( Type.enumEq(p, p2) )
				return true;
		return false;
	}
	
	@:noDebug
	public function getId() {
		if( props.length != 3 )
			throw name + " is not an object";
		return switch( props[0] ) {
		case PInt(id): id;
		case PFloat(id) : Std.int( id );
		default: throw name + " is not an object " + props;
		}
	}

	@:noDebug
	public inline function getName() {
		if( props.length != 3 )
			throw name + " is not an object";
		return switch( props[1] ) {
		case PString(n): n.split("::").pop();
		default: throw name + " is not an object";
		}
	}

	@:noDebug
	public inline function getType() {
		if( props.length != 3 )
			throw name + " is not an object";
		return switch( props[2] ) {
		case PString(n): n;
		default: throw name + " is not an object";
		}
	}
	
	@:noDebug
	public inline function getStringProp( idx:Int ) {
		return switch( props[idx] ) {
			case PString(n): n;
			default: throw name + " is not an object";
		}
	}
}

class FBxTools {
	public static function toString( n : FbxProp ) {
		if( n == null ) throw "null prop";
		return switch( n ) {
		case PString(v): v;
		default: throw "Invalid prop " + n;
		}
	}
	
	public static function toInt( n : FbxProp ) {
		if( n == null ) throw "null prop";
		return switch( n ) {
		case PInt(v): v;
		case PFloat(f): return Std.int( f );
		default: throw "Invalid prop " + n;
		}
	}

	public static function toFloat( n : FbxProp ) {
		if( n == null ) throw "null prop";
		return switch( n ) {
		case PInt(v): v * 1.0;
		case PFloat(v): v;
		default: throw "Invalid prop " + n;
		}
	}
}
