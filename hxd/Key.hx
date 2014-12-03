package hxd;

class Key {
	
	public static inline var BACKSPACE	= 8;
	public static inline var TAB		= 9;
	public static inline var ENTER		= 13;
	public static inline var SHIFT		= 16;
	public static inline var CTRL		= 17;
	public static inline var ALT		= 18;
	public static inline var ESCAPE		= 27;
	public static inline var SPACE		= 32;
	public static inline var PGUP		= 33;
	public static inline var PGDOWN		= 34;
	public static inline var END		= 35;
	public static inline var HOME		= 36;
	public static inline var LEFT		= 37;
	public static inline var UP			= 38;
	public static inline var RIGHT		= 39;
	public static inline var DOWN		= 40;
	public static inline var INSERT		= 45;
	public static inline var DELETE		= 46;
	
	public static inline var NUMBER_0	= 48;
	public static inline var NUMPAD_0	= 96;
	
	public static inline var A			= 65;
	public static inline var B			= 66;
	public static inline var C			= 67;
	public static inline var D			= 68;
	public static inline var E			= 69;
	public static inline var F			= 70;
	public static inline var G			= 71;
	public static inline var H			= 72;
	public static inline var I			= 73;
	public static inline var J			= 74;
	public static inline var K			= 75;
	public static inline var L			= 76;
	public static inline var M			= 77;
	public static inline var N			= 78;
	public static inline var O			= 79;
	public static inline var P			= 80;
	public static inline var Q			= 81;
	public static inline var R			= 82;
	public static inline var S			= 83;
	public static inline var T			= 84;
	public static inline var U			= 85;
	public static inline var V			= 86;
	public static inline var W			= 87;
	public static inline var X			= 88;
	public static inline var Y			= 89;
	public static inline var Z			= 90;
	
	//it seems these code are invalid on cpp
	#if flash
	public static inline var F1			= 112;
	public static inline var F2			= 113;
	public static inline var F3			= 114;
	public static inline var F4			= 115;
	public static inline var F5			= 116;
	public static inline var F6			= 117;
	public static inline var F7			= 118;
	public static inline var F8			= 119;
	public static inline var F9			= 120;
	public static inline var F10		= 121;
	public static inline var F11		= 122;
	public static inline var F12		= 123;
	#end
	
	public static inline var NUMPAD_MULT = 106;
	public static inline var NUMPAD_ADD	= 107;
	public static inline var NUMPAD_ENTER = 108;
	public static inline var NUMPAD_SUB = 109;
	public static inline var NUMPAD_DOT = 110;
	public static inline var NUMPAD_DIV = 111;
	
	public static inline var SQUARE = 222;
	
	static var initDone = false;
	static var keyPressed : Map<Int,Int> = new Map();
	
	public static function isDown( code : Int ) {
		return keyPressed[code] > 0;
	}

	//doesn't seem to work
	public static function isPressed( code : Int ) {
		return keyPressed[code] == h3d.Engine.getCurrent().frameCount+1;
	}

	//works
	public static function isReleased( code : Int ) {
		return keyPressed[code] == -(h3d.Engine.getCurrent().frameCount);
	}

	public static function initialize() {
		if( initDone )
			dispose();
		initDone = true;
		
		for ( i in 0...255)
			keyPressed[i] = 0;
		
		Stage.getInstance().addEventTarget(onKeyEvent);
		#if flash
		flash.Lib.current.stage.addEventListener(flash.events.Event.DEACTIVATE, onDeactivate);
		#end
	}
	
	public static function dispose() {
		if( initDone ) {
			Stage.getInstance().removeEventTarget(onKeyEvent);
			#if flash
			flash.Lib.current.stage.removeEventListener(flash.events.Event.DEACTIVATE, onDeactivate);
			#end
			initDone = false;
			keyPressed  = new Map();
		}
	}
	
	#if flash
	static function onDeactivate(_) {
		keyPressed = new Map();
	}
	#end
	
	static function onKeyEvent( e : Event ) {
		switch( e.kind ) {
		case EKeyDown:
			keyPressed[e.keyCode] = h3d.Engine.getCurrent().frameCount+1;
		case EKeyUp:
			keyPressed[e.keyCode] = -(h3d.Engine.getCurrent().frameCount+1);
		default:
		}
	}

}

