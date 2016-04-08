package hxd.fs;

#if !macro

@:allow(hxd.fs.LimeFileSystem)
@:access(hxd.fs.LimeFileSystem)
private class LimeEntry extends FileEntry {

	var fs : LimeFileSystem;
	var relPath : String;
	
	#if flash
	var bytes : flash.utils.ByteArray;
	#else
	var bytes : haxe.io.Bytes;
	var readPos : Int;
	#end

	var isReady:Bool = false;
	override function get_isAvailable() return isReady;
	
	function new(fs, name, relPath) {
		this.fs = fs;
		this.name = name;
		this.relPath = relPath;
	}

	override function getSign() : Int {
		#if flash
		var old = bytes == null ? 0 : bytes.position;
		open();
		bytes.endian = flash.utils.Endian.LITTLE_ENDIAN;
		var v = bytes.readUnsignedInt();
		bytes.position = old;
		return v;
		#else
		var old = readPos;
		open();
		readPos = old;
		return bytes.get(0) | (bytes.get(1) << 8) | (bytes.get(2) << 16) | (bytes.get(3) << 24);
		#end
	}

	override function getBytes() : haxe.io.Bytes {
		#if flash
		if( bytes == null )
			open();
		return haxe.io.Bytes.ofData(bytes);
		#else
		if( bytes == null )
			open();
		return bytes;
		#end
	}
	
	override function open() {
		if(lime.Assets.isLocal(path)) {
			var inBytes = lime.Assets.getBytes(path);
			if( inBytes == null ) throw "Missing resource " + path;
			#if flash
			bytes = inBytes.getData();
			bytes.position = 0;
			#else
			bytes = inBytes;
			readPos = 0;
			#end
			isReady = true;
		} else {
			//#if flash
			//	throw "Non embeded files are not supported on flash platform with Lime";
			//#else
			lime.Assets.loadBytes(path).onComplete(function(inBytes) {
				#if flash
				bytes = inBytes.getData();
				bytes.position = 0;
				#else
				bytes = inBytes;
				readPos = 0;
				#end
				isReady = true;
			});
			//#end
		}
	}
	
	override function skip( nbytes : Int ) {
		#if flash
		bytes.position += nbytes;
		#else
		readPos += nbytes;
		#end
	}
	
	override function readByte() : Int {
		#if flash
		return bytes.readUnsignedByte();
		#else
		return bytes.get(readPos++);
		#end
	}
	
	override function read( out : haxe.io.Bytes, pos : Int, size : Int ) : Void {
		#if flash
		bytes.readBytes(out.getData(), pos, size);
		#else
		out.blit(pos, bytes, readPos, size);
		readPos += size;
		#end
	}
	
	override function close() {
		bytes = null;
		#if !flash
		readPos = 0;
		#end
	}

	override function load( ?onReady : Void -> Void ) : Void {
		#if (flash || js)
		if( onReady != null ) haxe.Timer.delay(onReady, 1);
		#end
	}

	override function loadBitmap( onLoaded : LoadedBitmap -> Void ) : Void {
		#if flash
		var loader = new flash.display.Loader();
		loader.contentLoaderInfo.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function(e:flash.events.IOErrorEvent) {
			throw Std.string(e) + " while loading " + relPath;
		});
		loader.contentLoaderInfo.addEventListener(flash.events.Event.COMPLETE, function(_) {
			var content : flash.display.Bitmap = cast loader.content;
			onLoaded(new LoadedBitmap(content.bitmapData));
			loader.unload();
		});
		open();
		loader.loadBytes(bytes);
		close(); // flash will copy bytes content in loadBytes() !
		#else
		
		lime.graphics.Image.fromBytes(bytes, function(img) {
			onLoaded(new hxd.fs.LoadedBitmap(img));
		});
		close();
		#end
	}
	
	override function get_isDirectory() {
		return fs.isDirectory(relPath);
	}

	override function get_path() {
		return relPath == "." ? "<root>" : relPath;
	}

	override function exists( name : String ) {
		return fs.exists(relPath == "." ? name : relPath + "/" + name);
	}

	override function get( name : String ) {
		return fs.get(relPath == "." ? name : relPath + "/" + name);
	}

	override function get_size() {
		open();
		return bytes.length;
	}

	override function iterator() {
		return new hxd.impl.ArrayIterator(fs.subFiles(relPath));
	}
}

#end

class LimeFileSystem #if !macro implements FileSystem #end {

	var options:hxd.res.EmbedOptions;
	public function new(o) {
		this.options = o;
	}
	
	#if !macro
	public function getRoot() : FileEntry {
		return new LimeEntry(this,"root",".");
	}
	
	function splitPath( path : String ) {
		return path == "." ? [] : path.split("/");
	}

	function subFiles( path : String ) : Array<FileEntry> {
		var out:Array<FileEntry> = [];
		var all = lime.Assets.list();
		for( f in all ) {
			if( f != path && StringTools.startsWith(f, path) )
				out.push(get(f));
		}
		return out;
	}
	
	function checkPath(path:String) {
		if( StringTools.endsWith(path, ".wav") && options.compressSounds ) {
			#if flash
			if(options.compressAsMp3)
				return StringTools.replace(path, ".wav", ".mp3");
			#end
			return StringTools.replace(path, ".wav", ".ogg");
		}
		return path;
	}
	
	function isDirectory( path : String ) {
		return subFiles(path).length > 0;
	}
	
	public function exists( path : String ) {
		var path = checkPath(path);
		return lime.Assets.exists(path);
	}
	
	public function get( path : String ) {
		path = checkPath(path);
		if( !exists(path) )
			throw new NotFound(path);
		return new LimeEntry(this, path.split("/").pop(), path);
	}
	#end
	
	public function dispose() {
	}
	
	macro public static function build(?options:hxd.res.EmbedOptions) {
		path = hxd.res.FileTree.resolvePath(null);
		currentModule = Std.string(haxe.macro.Context.getLocalClass());
		//
		if( options == null ) 
			options = { compressSounds:false };
		if( options.tmpDir == null ) 
			options.tmpDir = path + "/.tmp/";
		if( options.tmpDir.charAt(options.tmpDir.length - 1) == "/" )
			options.tmpDir = options.tmpDir.substr(0, -1);
		// if the OGG library is detected, compress as OGG by default, unless compressAsMp3 is set
		if( options.compressAsMp3 == null )
			options.compressAsMp3 = options.compressSounds && !haxe.macro.Context.defined("stb_ogg_sound");
		//
		Sys.print("options:" + Std.string(options));
		if( options.compressSounds && !sys.FileSystem.exists(options.tmpDir) )
			sys.FileSystem.createDirectory(options.tmpDir);
		
		parseRec(options, '');
		return macro null;
	}
	
#if macro
	static var path:String;
	static var currentModule:String;
	static function parseRec(options, relPath : String) {
		var dir = LimeFileSystem.path + relPath;
		// make sure to rescan if one of the directories content has changed (file added or deleted)
		haxe.macro.Context.registerModuleDependency(currentModule, dir);
		for( f in sys.FileSystem.readDirectory(dir) ) {
			var path = dir + "/" + f;
			if( sys.FileSystem.isDirectory(path) ) {
				if( f.charCodeAt(0) == ".".code )
					continue;
				parseDir(options, f, relPath + "/" + f, path);
			} else {
				var extParts = f.split(".");
				var noExt = extParts.shift();
				var ext = extParts.join(".");
				parseFile(options, f, ext, relPath + "/" + f, path);
			}
		}
	}
	
	static function parseDir( options, dir : String, relPath : String, fullPath : String ) {
		return parseRec(options, relPath);
	}
	
	static function parseFile( options, file : String, ext : String, relPath : String, fullPath : String ) {
		var relative = StringTools.replace(fullPath, relPath, "");
		var relativepath = sys.FileSystem.fullPath(relative+"/../"+options.tmpDir);
		switch( ext.toLowerCase() ) {
		case "wav" if( options.compressSounds ):
			if( options.compressAsMp3 || !haxe.macro.Context.defined("stb_ogg_sound") ) {
				var tmp = relativepath + relPath;
				tmp = StringTools.replace(tmp, ".wav", ".mp3");
				if( getTime(tmp) < getTime(fullPath) ) {
					Sys.println("Converting " + relPath);
					try {
						hxd.snd.Convert.toMP3(fullPath, tmp);
					} catch( e : Dynamic ) {
						haxe.macro.Context.warning(e, haxe.macro.Context.currentPos());
					}
				}
				haxe.macro.Context.registerModuleDependency(currentModule, tmp);
			} else {
				var tmp = relativepath + relPath;
				tmp = StringTools.replace(tmp, ".wav", ".ogg");
				if( getTime(tmp) < getTime(fullPath) ) {
					Sys.println("Converting " + relPath);
					try {
						hxd.snd.Convert.toOGG(fullPath, tmp);
					} catch( e : Dynamic ) {
						haxe.macro.Context.warning(e, haxe.macro.Context.currentPos());
					}
				}
				haxe.macro.Context.registerModuleDependency(currentModule, tmp);
			}
		default:
		}
		return fullPath;
	}
	
	static function getTime( file : String ) {
		return try sys.FileSystem.stat(file).mtime.getTime() catch( e : Dynamic ) -1.;
	}
#end

}
