package hxd.res;

class Loader {
	
	public var fs(default,null) : FileSystem;
	var cache : Map<String,Dynamic>;
	
	public function new(fs) {
		this.fs = fs;
		cache = new Map<String,Dynamic>();
	}

	public function exists( path : String ) : Bool {
		return fs.exists(path);
	}
	
	public function load( path : String ) : Any {
		return new Any(this, fs.get(path));
	}
	
	function loadTexture( path : String ) : Texture {
		var t = cache.get(path);
		if( t == null ) {
			t = new Texture(fs.get(path));
			cache.set(path, t);
		}
		return t;
	}
	
	function loadModel( path : String ) : Model {
		var m = cache.get(path);
		if( m == null ) {
			m = new Model(fs.get(path));
			cache.set(path, m);
		}
		return m;
	}

	/*
	function loadAwdModel( path : String ) : AwdModel {
		var m : AwdModel = cache.get(path);
		if( m == null ) {
			m = new AwdModel(fs.get(path));
			cache.set(path, m);
		}
		return m;
	}
	*/
	/*
	function loadImage( path : String ) : Image {
		var i : Image = cache.get(path);
		if( i == null ) {
			i = new Image(fs.get(path));
			cache.set(path, i);
		}
		return t;
	}*/
	
	function loadSound( path : String ) : Sound {
		var s : Sound = cache.get(path);
		if( s == null ) {
			s = new Sound(fs.get(path));
			cache.set(path, s);
		}
		return s;
	}

	function loadFont( path : String ) : Font {
		// no cache necessary (uses FontBuilder which has its own cache)
		return new Font(fs.get(path));
	}

	function loadBitmapFont( path : String ) : BitmapFont {
		var f : BitmapFont = cache.get(path);
		if( f == null ) {
			f = new BitmapFont(this,fs.get(path));
			cache.set(path, f);
		}
		return f;
	}

	function loadData( path : String ) {
		return new Resource(fs.get(path));
	}
	
	#if tilemap
	function loadTiledMap( path : String ) {
		return new TiledMap(fs.get(path));
	}
	#end
	
	function loadGradients( path : String ) {
		return new Gradients(fs.get(path));
	}
	
}