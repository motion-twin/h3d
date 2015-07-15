package hxd;

enum EventKind {
	EPush;
	ERelease;
	EMove;
	EOver;
	EOut;
	EWheel;
	EFocus;
	EFocusLost;
	EKeyDown;
	EKeyUp;
	
	ESimulated;
}

class Event {

	public var kind 		: EventKind;
	public var relX 		: Float;
	public var relY 		: Float;
	public var propagate 	: Bool;
	public var cancel 		: Bool;
	public var button 		: Int;
	public var touchId 		: Int;
	public var keyCode 		: Int;
	public var charCode 	: Int;
	public var wheelDelta 	: Float;
	
	public function new(k,x=0.,y=0.) {
		kind = k;
		this.relX = x;
		this.relY = y;
	}
	
	public function toString() {
		return kind + "[" + Std.int(relX) + "," + Std.int(relY) + "]";
	}
	
	public function clone() {
		var e = new Event(kind);
		
		e.relX 		    = relX 		       ;
		e.relY 		    = relY 		       ;
		e.propagate     = propagate        ;
		e.cancel 		= cancel 		   ;
		e.button 		= button 		   ;
		e.touchId 		= touchId 		   ;
		e.keyCode 		= keyCode 		   ;
		e.charCode 	    = charCode 	       ;
		e.wheelDelta    = wheelDelta       ;
		
		return e;
	}
}