package hxd.text;

class Utf8Tools {
	public static function getLastBits( code , nth ) 	{
		var mask = ((1 << (nth))-1);
		return (code & mask);
	};

	public static function toCharCode(str:String) {
		var c0 = str.charCodeAt(0);
		if ( c0 & (1 << 8) == 0) {
			return getLastBits(c0, 7);
		}
		else if ( c0 & (1 << 6) == 0) { //11 bits
			return (getLastBits(c0, 5) << 6) | getLastBits(str.charCodeAt(1), 6);
		}
		else if ( c0 & (1 << 5) == 0) { //16 bits
			return (getLastBits(c0, 4) << 12) | (getLastBits(str.charCodeAt(1), 6)<<6) | (getLastBits(str.charCodeAt(2), 6));
		}
		else { // 21 bits
			return (getLastBits(c0, 3) << 18) | (getLastBits(str.charCodeAt(1), 6)<<12) | (getLastBits(str.charCodeAt(2), 6)<<6) | (getLastBits(str.charCodeAt(3), 6));
		}
	}
	
	public static function getByteLength(cc:Int) {
		if ( cc < (1<<7)-1 ) return 1;
		else if ( cc < (1<<11)-1 ) return 2;
		else if ( cc < (1<<16)-1 ) return 3;
		else return 4;
	}
}