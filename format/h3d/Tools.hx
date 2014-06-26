package format.h3d;
import h3d.Matrix;
import haxe.ds.Vector;
import haxe.io.Bytes;
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
	
	/**
	 * 4-packed loop that goes way faster..same speed on flash, 4 time faster on cpp
	 */
	public static function floatVectorToFloatBytesFast( vs : Vector<Float> ) : Bytes {
		var b = haxe.io.Bytes.alloc( vs.length * 4 );
		
		var rest = (vs.length & 3);
		var nb = vs.length - rest;
		var onb = nb;
		
		var i = 0;
		var pos = 0;
		while ( i < nb ) {
			pos = i << 2;
			b.setFloat( pos, 		vs[i]);				
			b.setFloat( pos+4, 		vs[i+1]);	
			b.setFloat( pos+8, 		vs[i+2]);	
			b.setFloat( pos+12, 	vs[i+3]);
			i+=4;
		}
		
		for ( i in onb...vs.length)
			b.setFloat( i<<2,vs[i]);
		
		return b;
	}
	
	
	public static function test() {
		var n = 10000;
		var v :Vector<Float> = new Vector(n);
		for ( i in 0...v.length)
			v[i] = i;
		
		var t0 = Timer.stamp();
		var b = floatVectorToFloatBytesFast(v);
		if ( b.getFloat( b.length - 4) != n-1 )
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
			
		var a = 0;
	}
	
}