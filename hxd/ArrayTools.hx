package hxd;

class ArrayTools {

	@:generic
	public static inline function unsafeGet<T>( a:Array<T>, i : Int){
		return a[i];
	}
	
	@:generic
	public inline static function unsafeSet<T>( a:Array<T>, i : Int,v:T){
		return a[i]=v;
	}
	
	public static inline function zeroF(t : Array<Float>) {
		for ( i in 0...t.length) t[i] = 0.0;
	}
	
	public static inline function zeroI(t : Array<Int>) {
		for ( i in 0...t.length) t[i] = 0;
	}
	
	public static inline function zeroNull<T>(t : Array<T>) {
		for ( i in 0...t.length) t[i] = null;
	}
	
	public static inline function blit(d : Array<Float>, ?dstPos = 0, src:Array<Float>, ?srcPos = 0, ?nb = -1) {
		if ( nb < 0 )  nb = src.length;
		
		for ( i in 0...nb)
			d[i+dstPos] = src[i+srcPos];
	}
	
}