package hxd.tools;

import haxe.ds.Vector;

class VectorTools {
	
	public static inline function blitArray<T>( target:Vector<T>, arr:Array<T>){
		if( target.length < arr.length) throw "blitArray.assert";
		for( i in 0...arr.length )
			target[i]=arr[i];
	}
}