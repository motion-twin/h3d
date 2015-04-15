using StringTools;


@:publicFields
class Path{
	static function getFile(path:String) :String{
		path = path.replace("\\", "/");
		var a = path.split("/");
		return a[a.length - 1];
	}
	
	static function getBaseDir(path) {
		var root = sys.FileSystem.fullPath(path);
		root = root.replace("\\", "/");
		var dir = root.split("/");
		dir.splice(dir.length - 1, 1);
		root = dir.join("/");
		return root+"/";
	}
	
	static function getDir(path:String):String {
		var root = path;
		root = root.replace("\\", "/");
		var dir = root.split("/");
		dir.splice(dir.length - 1, 1);
		root = dir.join("/");
		return root+"/";
	}
	
	static function makeRelative(path) {
		var cwd = Sys.getCwd();
		return path.substr(cwd.length, path.length);
	}
	
	static function removeLastExtension(path) {
		var a = path.split(".");
		if ( a.length > 1 )
			a.splice( a.length - 1, 1);
		return a.join(".");
	}
	
	static function normalize(str:String):String {
		return str.replace("\\", "/");
	}
}
