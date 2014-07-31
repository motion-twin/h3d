package h2d.comp;

class ScrollController {
	public var locked : Bool;
	public var scroll : Float;
	public var startScroll : Float;

	public var startEvt : Null<Float>;
	public var lastEvt : Null<Float>;
	public var lastDiff : Float;
	public var inerty = 0.0;
	public var frict = 1.0;

	public var minScroll : Float;

	public var tweenDest : Float;
	public var tweenCur : Null<Float>;
	public var tweenT : Float;

	public var doScroll : Float -> Bool -> Void;

	public function onPush( curScroll : Float, evtPos : Float ){
		if( locked )
			return;
		scroll = startScroll = curScroll;

		startEvt = lastEvt = evtPos;

		locked = false;
		lastDiff = 0.0;
		inerty = 0.0;
		tweenCur = null;
	}

	public function onRelease(){
		if( locked )
			return;

		startEvt = null;
		if( Math.abs(lastDiff) > 6 )
			inerty = lastDiff;
		else
			checkRecal();
	}

	public function onMove( evtPos : Float ){
		if( locked || startEvt == null )
			return;
		
		var diff = evtPos - lastEvt;
		if( diff != 0 ){
			lastEvt = evtPos;
			var nPos = startScroll + (evtPos - startEvt);

			diff *= frict = updateFrict( nPos, diff );
			lastDiff = diff;

			doScroll( scroll = scroll + diff, true );
		}
	}
	
	public inline function onSync(){
		if( !locked && tweenCur != null ){
			var old = tweenT;
			tweenT = haxe.Timer.stamp();
			var d = tweenT - old;
			tweenCur += d * 2.8;

			if( tweenCur > 1 )
				tweenCur = 1;

			doScroll( scroll = startScroll + (tweenDest - startScroll) * tweenCur, false );
			if( tweenCur >= 1 )
				tweenCur = null;
		}else if( !locked && inerty != 0.0 ){
			inerty *= 0.98;
			frict = updateFrict( scroll+inerty, inerty );
			inerty = inerty * frict * frict;
			doScroll( scroll = scroll + inerty, false );
			if( (inerty > -1.0 && inerty < 1.0) || scroll < minScroll || scroll > 0 ){
				inerty = 0.0;
				checkRecal();
			}
		}
	}

	inline function updateFrict( nPos : Float, diff : Float ){
 		return frict = if ( (nPos > 0 && diff > 0) || (nPos < minScroll && diff < 0) )
 			Math.max(0.15, frict- 0.06) ;
 		else 
 			1.0 ;
	}

	function checkRecal(){
		if( scroll >= minScroll && scroll <= 0 )
			return;

		startScroll = scroll;
		tweenDest = scroll > 0 ? 0 : minScroll;
		tweenCur = 0.0;
		tweenT = haxe.Timer.stamp();
	}

}

class Scroll extends Box {

	var controlX : ScrollController;
	var controlY : ScrollController;

	var moved : Bool;
	var sinput : h2d.Interactive;
	
	public function new(?layout,?parent,?name) {
		super(layout,parent);
		this.name = name;

		controlX = new ScrollController();
		controlX.doScroll = function(d,b){
			scrollX = d;
			if( b )
				moved = true;
			refresh();
		}
		controlX.locked = name=="vscroll";

		controlY = new ScrollController();
		controlY.doScroll = function(d,b){
			scrollY = d;
			if( b )
				moved = true;
			refresh();
		}
		controlY.locked = name=="hscroll";
	}

	function onPush( e : hxd.Event ) {
		controlX.minScroll = contentWidth - scrollWidth;
		if ( controlX.minScroll > 0 ) controlX.minScroll = 0;

		controlY.minScroll = contentHeight - scrollHeight;
		if ( controlY.minScroll > 0 ) controlY.minScroll = 0;

		controlX.onPush( scrollX, e.relX );
		controlY.onPush( scrollY, e.relY );

		moved = false;
	}

	function onRelease( e : hxd.Event ){
		if ( moved ) {
			e.propagate = false;
			e.cancel = true;
		}

		controlX.onRelease();
		controlY.onRelease();

		moved = false;
	}

	function onMove( e : hxd.Event ){
		controlX.onMove( e.relX );
		controlY.onMove( e.relY );
		if( !moved )
			e.cancel = true;
	}

	override function sync(ctx){
		super.sync(ctx);

		controlX.onSync();
		controlY.onSync();
	}

	override function resizeRec( ctx : Context ) {
		super.resizeRec(ctx);
		if( ctx.measure ){
		}else{
			if( sinput == null ){
				sinput = new h2d.Interactive(0, 0, this);
				sinput.cursor = Default;
				sinput.onPush = onPush;
				sinput.onRelease = onRelease;
				sinput.onMove = onMove;
				sinput.propagateEvents = true;
			}
			sinput.width = width - (style.marginLeft + style.marginRight);
			sinput.height = height - (style.marginTop + style.marginBottom);
		}
	}
	

}
