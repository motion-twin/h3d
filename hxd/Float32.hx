package hxd;

#if (cpp&&(hxcpp_api_level >= 312))
typedef Float32 = cpp.Float32;
#else
typedef Float32 = std.StdTypes.Float;
#end

