package format.h3d;
import h3d.Matrix;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.Timer;

class Tools {
	
	public static function matrixVectorToFloatBytes( ms : Vector<h3d.Matrix> ) : Bytes {
		var b = haxe.io.Bytes.alloc( ms.length << (2+4)  );
		var pos = 0;
		
		for ( m in ms ) {
			
			b.setFloat( pos		, m._11 ); 
			b.setFloat( pos+4	, m._12 ); 
			b.setFloat( pos+8	, m._13 ); 
			b.setFloat( pos+12	, m._14 ); 
			
			pos += 16;
			                          
			b.setFloat( pos		, m._21 ); 
			b.setFloat( pos+4	, m._22 ); 
			b.setFloat( pos+8	, m._23 ); 
			b.setFloat( pos+12	, m._24 ); 
			
			pos += 16;
			                         
			b.setFloat(	pos		, m._31 ); 
			b.setFloat(	pos+4	, m._32 ); 
			b.setFloat(	pos+8	, m._33 ); 
			b.setFloat(	pos+12	, m._34 ); 
			
			pos += 16;
			                          
			b.setFloat( pos		, m._41 ); 
			b.setFloat( pos+4	, m._42 ); 
			b.setFloat( pos+8	, m._43 ); 
			b.setFloat( pos+12	, m._44 ); 
			
			pos += 16;
		}
		
		return b;
	}
	
	public static function matrixVectorToFloatBytesFast( ms : Vector<h3d.Matrix> ) : Bytes {
		var b = haxe.io.Bytes.alloc( ms.length << (2+4)  );
		var pos = 0;
		
		for ( m in ms ) {
			
			setFloat(b,pos		, m._11 ); 
			setFloat(b,pos+4	, m._12 ); 
			setFloat(b,pos+8	, m._13 ); 
			setFloat(b,pos+12	, m._14 ); 
			           
			pos += 16; 
			                         
			setFloat(b,pos		, m._21 ); 
			setFloat(b,pos+4	, m._22 ); 
			setFloat(b,pos+8	, m._23 ); 
			setFloat(b,pos+12	, m._24 ); 
			           
			pos += 16; 
			                        
			setFloat(b,pos		, m._31 ); 
			setFloat(b,pos+4	, m._32 ); 
			setFloat(b,pos+8	, m._33 ); 
			setFloat(b,pos+12	, m._34 ); 
			           
			pos += 16; 
			                         
			setFloat(b,pos	, m._41 ); 
			setFloat(b,pos+4	, m._42 ); 
			setFloat(b,pos+8	, m._43 ); 
			setFloat(b,pos+12	, m._44 ); 
			
			pos += 16;
		}
		
		return b;
	}
	
	
	public static function floatVectorToFloatBytes( vs : Vector<Float> ) : Bytes {
		var b = haxe.io.Bytes.alloc(vs.length * 4  );
		var pos = 0;
		for ( v in vs ) {
			b.setFloat( pos, v );
			pos += 4;
		}
		return b;
	}
	
	public static function floatBytesToFloatVector( bytes : haxe.io.Bytes ) : Vector<Float>  {
		var nb = bytes.length >> 2;
		var v = new Vector( nb );
		for (i in 0...nb) v[i] =  bytes.getFloat(i << 2); 
		return v;
	}
	
	public static function floatBytesToMatrixVectorFast( bytes : haxe.io.Bytes ) : Vector<h3d.Matrix>  {
		var nbMatrix = (bytes.length >> (2 + 4) );
		var v : haxe.ds.Vector<Matrix>= new Vector( nbMatrix );
		
		var pos = 0;
		for (i in 0...nbMatrix) {
			var m = Type.createEmptyInstance( h3d.Matrix );
			
			m._11 = getFloat( bytes,pos );
			m._12 = getFloat( bytes,pos+4 );
			m._13 = getFloat( bytes,pos+8 );
			m._14 = getFloat( bytes,pos+12 );
			
			pos += 16;
			
			m._21 = getFloat( bytes,pos );
			m._22 = getFloat( bytes,pos+4 );
			m._23 = getFloat( bytes,pos+8 );
			m._24 = getFloat( bytes,pos+12 );
			
			pos += 16;
			
			m._31 = getFloat( bytes,pos );
			m._32 = getFloat( bytes,pos+4 );
			m._33 = getFloat( bytes,pos+8 );
			m._34 = getFloat( bytes,pos+12 );
			
			pos += 16;
			
			m._41 = getFloat( bytes,pos );
			m._42 = getFloat( bytes,pos+4 );
			m._43 = getFloat( bytes,pos+8 );
			m._44 = getFloat( bytes,pos+12 );
			
			pos += 16;
			
			v[i] = m;
		}
		
		return v;
	}
	
	
	public static function floatBytesToMatrixVector( bytes : haxe.io.Bytes ) : Vector<h3d.Matrix>  {
		var nbMatrix = (bytes.length >> (2 + 4) );
		var v : haxe.ds.Vector<Matrix>= new Vector( nbMatrix );
		
		var pos = 0;
		for (i in 0...nbMatrix) {
			var m = Type.createEmptyInstance( h3d.Matrix );
			
			m._11 = bytes.getFloat( pos );
			m._12 = bytes.getFloat( pos+4 );
			m._13 = bytes.getFloat( pos+8 );
			m._14 = bytes.getFloat( pos+12 );
			
			pos += 16;
			
			m._21 = bytes.getFloat( pos );
			m._22 = bytes.getFloat( pos+4 );
			m._23 = bytes.getFloat( pos+8 );
			m._24 = bytes.getFloat( pos+12 );
			
			pos += 16;
			
			m._31 = bytes.getFloat( pos );
			m._32 = bytes.getFloat( pos+4 );
			m._33 = bytes.getFloat( pos+8 );
			m._34 = bytes.getFloat( pos+12 );
			
			pos += 16;
			
			m._41 = bytes.getFloat( pos );
			m._42 = bytes.getFloat( pos+4 );
			m._43 = bytes.getFloat( pos+8 );
			m._44 = bytes.getFloat( pos+12 );
			
			pos += 16;
			
			v[i] = m;
		}
		
		return v;
	}
	
	
	#if (flash ||debug)
	inline static function getFloat(bytes:haxe.io.Bytes, pos) : Float return bytes.getFloat(pos);
	#elseif cpp
	inline static function getFloat(bytes:haxe.io.Bytes, pos : Int ) : Float
		return untyped __global__.__hxcpp_memory_get_float(bytes.b,pos);
	#end
	
	#if (flash ||debug) 
	inline static function setFloat(bytes:haxe.io.Bytes, pos, v:Float) : Void 
		bytes.setFloat(pos,v);
	#elseif cpp
	inline static function setFloat(bytes:haxe.io.Bytes, pos : Int,v:Float ) 
		untyped __global__.__hxcpp_memory_set_float(bytes.b,pos,v);
	#end
	
	public static function floatBytesToFloatVectorFast( bytes : haxe.io.Bytes ) : Vector<Float>  {
		var nbFloats = bytes.length >> 2;
		
		var rest = nbFloats & 3;
		var nb = nbFloats - rest;
		
		var vs = new Vector( nb );
		var i = new BytesInput(bytes);
		
		var i = 0;
		var pos = 0;
		
		while ( i < nb ) {
			pos = i << 2;
			vs[i]	= getFloat(bytes, pos);
			vs[i+1]	= getFloat(bytes, pos + 4);
			vs[i+2]	= getFloat(bytes, pos + 8);
			vs[i+3] = getFloat(bytes, pos + 12);
			i+=4;
		}
		
		for ( i in nb...nbFloats)
			vs[i] =  getFloat(bytes,  i << 2 );		
		
		return vs;
	}
	
	/**
	 * 4-packed loop that goes way faster..same speed on flash, 4 time faster on cpp
	 */
	public static function floatVectorToFloatBytesFast( vs : Vector<Float> ) : Bytes {
		var b = haxe.io.Bytes.alloc( vs.length * 4 );
		
		var rest = (vs.length & 3);
		var nb = vs.length - rest;
		
		var i = 0;
		var pos = 0;
		while ( i < nb ) {
			pos = i << 2;
			setFloat( b,pos, 		vs[i]);				
			setFloat( b,pos+4, 		vs[i+1]);	
			setFloat( b,pos+8, 		vs[i+2]);	
			setFloat( b,pos+12, 	vs[i+3]);
			i+=4;
		}
		
		for ( i in nb...vs.length)
			setFloat( b,i<<2,vs[i]);
		
		return b;
	}
	
	
	public static function test() {
		var n = 20000;
		var v :Vector<Float> = new Vector(n);
		for ( i in 0...v.length)
			v[i] = i;
		
		var t0 = Timer.stamp();
		var bFloat = floatVectorToFloatBytesFast(v);
		if ( bFloat.getFloat( bFloat.length - 4) != n-1 )
			throw "assert";
		var t1 = Timer.stamp();
		var totalFast = t1 - t0;
		trace("totalFast:" + totalFast + "s");
		
		var t0 = Timer.stamp();
		var b = floatVectorToFloatBytes(v);
		if ( b.getFloat( b.length - 4) != n-1 )
			throw "assert";
		var t1 = Timer.stamp();
		var totalNaive = t1 - t0;
		trace("totalNaive:" + totalNaive+"s");
		
		var t0 = Timer.stamp();
		var b = floatBytesToFloatVector(bFloat);
		if ( b[b.length-1] != n-1 )
			throw "assert";
		var t1 = Timer.stamp();
		var totalNaive = t1 - t0;
		trace("totalNaive:" + totalNaive+"s");
		
		var t0 = Timer.stamp();
		var b = floatBytesToFloatVectorFast(bFloat);
		if ( b[b.length-1] != n-1 )
			throw "assert";
		var t1 = Timer.stamp();
		var totalNaive = t1 - t0;
		trace("totalFast:" + totalNaive+"s");
			
		var a = 0;
	}
	
}