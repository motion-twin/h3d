package hxd;

class ArrayTools {

	@:generic
	public static inline function unsafeGet<T>( a:Array<T>, i : Int){
		#if cpp
		return untyped a.__unsafe_get(i);
		#else 
		return a[i];
		#end
	}
	
	@:generic
	public inline static function unsafeSet<T>( a:Array<T>, i : Int,v:T){
		#if cpp
		return cast( untyped a.__unsafe_set(i, v));
		#else 
		return a[i]=v;
		#end
	}
	
	public static inline function zeroF(t : Array<Float>) {
		#if cpp
			untyped t.__unsafe_zeroMemory();
		#else
			for ( i in 0...t.length) t[i] = 0.0;
		#end
	}
	
	public static inline function zeroI(t : Array<Int>) {
		#if cpp
			untyped t.__unsafe_zeroMemory();
		#else
			for ( i in 0...t.length) t[i] = 0;
		#end
	}
	
	public static inline function zeroNull<T>(t : Array<T>) {
		#if cpp
			untyped t.__unsafe_zeroMemory();
		#else
			for ( i in 0...t.length) t[i] = null;
		#end
	}
	

	
	public static inline function blit(d : Array<Float>, ?dstPos = 0, src:Array<Float>, ?srcPos = 0, ?nb = -1) {
		if ( nb < 0 )  nb = src.length;
		#if cpp
			untyped d.__unsafe_blit(dstPos,src,srcPos,nb);
		#else
			for ( i in 0...nb)
				d[i+dstPos] = src[i+srcPos];
		#end
	}
	
}