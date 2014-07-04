package hxd.fmt.bson;

import haxe.io.Bytes;
import haxe.io.Input;

/*
 * @author Andre Lacasse
 * @author Matt Tuttle
 * @author Motion Twin
 */
class BSON
{

	public inline static function encode(o:Dynamic):Bytes {
		return new BSONEncoder(o).getBytes();
	}

	public inline static function decode(i:Input):Dynamic {
		return new BSONDecoder(i).getObject();
	}

}