package hxd.fmt.h3d;

import flash.utils.ByteArray;
import h3d.Matrix;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.Timer;
import hxd.ByteConversions;
import hxd.IndexBuffer;

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
	
	public static function matrixToBytes( m  : h3d.Matrix ) : haxe.io.Bytes {
		var b = haxe.io.Bytes.alloc( 16 * 4  );
		var pos = 0;
		
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
		
		return b;
	}
	
	public static function bytesToMatrix(b : haxe.io.Bytes ) : h3d.Matrix {
		var pos = 0;
		var m = new h3d.Matrix();
		m._11 = b.getFloat( pos		); 
		m._12 = b.getFloat( pos+4	); 
		m._13 = b.getFloat( pos+8	); 
		m._14 = b.getFloat( pos+12	); 
		pos += 16;
		  						
		m._21 = b.getFloat( pos		); 
		m._22 = b.getFloat( pos+4	); 
		m._23 = b.getFloat( pos+8	); 
		m._24 = b.getFloat( pos+12	); 
		
		pos += 16;
		 						
		m._31 = b.getFloat(	pos		); 
		m._32 = b.getFloat(	pos+4	); 
		m._33 = b.getFloat(	pos+8	); 
		m._34 = b.getFloat(	pos+12	); 
		
		pos += 16;
		  						
		m._41 = b.getFloat( pos		); 
		m._42 = b.getFloat( pos+4	); 
		m._43 = b.getFloat( pos+8	); 
		m._44 = b.getFloat( pos + 12	); 
		return m;
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
	
	public static function floatArrayToBytes( vs : Array<Float> ) : Bytes {
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
	
	public static function intArrayToBytes(arr:Array<Int>) : haxe.io.Bytes {
		var ba = new flash.utils.ByteArray();
		ba.endian = flash.utils.Endian.LITTLE_ENDIAN;
		for ( i in arr )ba.writeInt( i );
		return ByteConversions.byteArrayToBytes(ba);
	}
	
	public static function bytesToFloatArray(bytes:haxe.io.Bytes) : Array<Float>{
		var arr = [];
		var pos = 0;
		for ( i in 0...(bytes.length>>2) ){
			arr.push( bytes.getFloat(pos) );
			pos += 4;
		}
		return arr;
	}
	
	public static function intVectorToBytes(arr:haxe.ds.Vector<Int>) : haxe.io.Bytes {
		var ba = new flash.utils.ByteArray();
		ba.endian = flash.utils.Endian.LITTLE_ENDIAN;
		for ( i in arr ) ba.writeInt( i );
		return ByteConversions.byteArrayToBytes(ba);
	}
	
	public static function bytesToIntVector( bytes : haxe.io.Bytes ) : haxe.ds.Vector<Int>{
		var b = new BytesInput( bytes );
		var nbInt = b.length >> 2;
		var v = new Vector( b.length >> 2 );
		for ( i in 0...nbInt ) 
			v[i] = b.readInt32();
		return v;
	}
	
	public static function bytesToIntArray( bytes : haxe.io.Bytes ) : Array<Int>{
		var b = new BytesInput( bytes );
		var nbInt = b.length >> 2;
		var v = [];
		
		v[nbInt - 1] = 0;
		
		for ( i in 0...nbInt ) 
			v[i] = b.readInt32();
			
		return v;
	}
	
	public static function indexbufferToBytes(arr:hxd.IndexBuffer) : haxe.io.Bytes {
		var ba = new flash.utils.ByteArray();
		ba.endian = flash.utils.Endian.LITTLE_ENDIAN;
		
		for ( i in arr )
			ba.writeInt( i );
		
		return ByteConversions.byteArrayToBytes(ba);
	}
	
	public static function writeVector4( output:haxe.io.Output, vec:h3d.Vector ) {
		output.writeFloat( vec.x );
		output.writeFloat( vec.y );
		output.writeFloat( vec.z );
		output.writeFloat( vec.w );
	}
	
	public static function condWriteVector4( output:haxe.io.Output, vec:Null<h3d.Vector> ) {
		writeBool( output,vec !=null);
		if( vec!=null ) condWriteVector4(output, vec);
	}
	
	public static function writeBool( output:haxe.io.Output, b:Bool ){
		output.writeByte( b ? 1 : 0 );
	}
	
	public static function readBool( input:haxe.io.Input) : Bool {
		return input.readByte()==1?true:false;
	}
	
	public static function readVector4(input:haxe.io.Input):h3d.Vector {
		var x = input.readFloat();
		var y = input.readFloat(); 
		var z = input.readFloat();
		var w = input.readFloat();
		return new h3d.Vector(x,y,z,w);
	}
	
	public static function condReadVector4( input:haxe.io.Input ) : Null<h3d.Vector> {
		if ( readBool(input) )
			return readVector4(input);
		else 
			return null;
	}
	
	public static function condWriteBytes2( output:haxe.io.Output, b:Null<haxe.io.Bytes> ) {
		writeBool( output, b != null);
		if( b != null){
			output.writeInt32(b.length);
			output.write(b);
		}
	}
	
	public static function writeBytes2( output:haxe.io.Output, b:haxe.io.Bytes ) {
		output.writeInt32(b.length);
		output.write(b);
	}
	
	public static function readBytes2( input:haxe.io.Input ) : haxe.io.Bytes{
		var len = input.readInt32();
		return input.read( len );
	}
	
	public static function condReadBytes2(input):Null<haxe.io.Bytes> {
		if ( readBool(input)) {
			return readBytes2( input );
		}
		else return null;
	}
	
	public static function condReadString2(input):Null<String> {
		if ( readBool(input))	return readString2( input );
		else 					return null;
	}
	
	public static function writeString2( output:haxe.io.Output, str:String ) {
		output.writeInt32( str.length );
		output.writeString( str );
	}
	
	public static function condWriteString2( output:haxe.io.Output, str:Null<String> ) {
		writeBool( output, str != null );
		if ( str != null)	writeString2(output,str);
	}
	
	public static function readString2( input:haxe.io.Input ) : String {
		var len = input.readInt32();
		return input.readString( len );
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
