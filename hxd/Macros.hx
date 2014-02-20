package hxd;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.Utf8;

class Macros {

	macro static public function getCharCode(str:String):ExprOf<Int> {
		var u8 = Utf8.charCodeAt(str,0);
		return macro $v{u8};
    }
	
}