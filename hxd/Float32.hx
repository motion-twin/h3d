package hxd;

#if (haxe_ver >= 3.13)
	#if cpp
	typedef Float32 = cpp.Float32;
	#else
	typedef Float32 = std.StdTypes.Float;
	#end
#else
typedef Float32 = std.StdTypes.Float;
#end

