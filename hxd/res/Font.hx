package hxd.res;

class Font extends Resource {

	public function build( size : Int, ?options ) : h2d.Font {
		#if lime
		var fontName = #if flash  lime.Assets.getFont(name).name #else this.name #end;
		return FontBuilder.getFont(fontName, size, options);
		#elseif flash
		var fontClass : Class<flash.text.Font> = cast Type.resolveClass("_R_" + ~/[^A-Za-z0-9_]/g.replace(entry.path, "_"));
		if( fontClass == null ) throw "Embeded font not found " + entry.path;
		var font = Type.createInstance(fontClass, []);
		return FontBuilder.getFont(font.fontName, size, options);
		#elseif js
		var name = "R_" + ~/[^A-Za-z0-9_]/g.replace(entry.path, "_");
		return FontBuilder.getFont(name, size, options);
		#else
		throw "Not implemented for this platform";
		return null;
		#end
	}

}
