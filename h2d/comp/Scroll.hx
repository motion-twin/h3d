package h2d.comp;

class ScrollController {
	public var locked : Bool;
	public var scroll : Float = 0.0;
	public var startScroll : Float = 0.0;

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

/**
 * This components is made to be controlled by the html, css, manual control is...undocumented.
 * to use, setup a scroll with a small width,
 * the content will be scrolled 
 * the content should have a fixed width
 * the scroll itself should have a fixed width
 */
class Scroll extends Box {
	
	public static var CANCEL_CLICK_DELTA = 5.;

	public var controlX(default,null) : ScrollController;
	public var controlY(default,null) : ScrollController;

	var moveDelta : Float;
	var sinput : h2d.Interactive;
	
	public function new(?layout,?parent,?name) {
		super(layout,parent);
		this.name = name;
		this.moveDelta = 0.;

		controlX = new ScrollController();
		controlX.doScroll = function(d,b){
			var diff = d-scrollX;
			if( diff != 0 ){
				scrollX = d;
				if( b )
					moveDelta += Math.abs(diff);
				for( c in components ){
					if( c.visible )
						c.x += diff;
				}
			}
		}
		controlX.locked = name=="vscroll";

		controlY = new ScrollController();
		controlY.doScroll = function(d,b){
			var diff = d-scrollY;
			if( diff != 0 ){
				scrollY = d;
				if( b )
					moveDelta += Math.abs(diff);
				for( c in components ){
					if( c.visible )
						c.y += diff;
				}
			}
		}
		controlY.locked = name == "hscroll";
		
		
	}

	public dynamic function onActivity() {
		
	}
	
	public dynamic function onMouseWheel(e : hxd.Event) {
		onPush(e);
		var ee = e.clone();
		ee.relY -= 10.0 * e.wheelDelta;
		onMove(ee);
		onRelease(ee);
	}
	
	function onPush( e : hxd.Event ) {
		controlX.minScroll = contentWidth - scrollWidth;
		if ( controlX.minScroll > 0 ) controlX.minScroll = 0;

		controlY.minScroll = contentHeight - scrollHeight;
		if ( controlY.minScroll > 0 ) controlY.minScroll = 0;

		controlX.onPush( scrollX, e.relX );
		controlY.onPush( scrollY, e.relY );

		moveDelta = 0.;
		
		onActivity();
	}

	function onRelease( e : hxd.Event ){
		if ( moveDelta >= CANCEL_CLICK_DELTA ) {
			e.propagate = false;
			getScene().cleanPushList();
		}

		controlX.onRelease();
		controlY.onRelease();

		moveDelta = 0.;
		
		onActivity();
	}

	function onMove( e : hxd.Event ){
		controlX.onMove( e.relX );
		controlY.onMove( e.relY );
		
		if( moveDelta >= CANCEL_CLICK_DELTA )
			onActivity();
			
		if( sinput!=null)
			sinput.focus();
			
		if( moveDelta < CANCEL_CLICK_DELTA )
			e.cancel = true;
	}

	override function sync(ctx){
		super.sync(ctx);

		controlX.onSync();
		controlY.onSync();
	}

	override function resizeRec( ctx : Context ) {
		super.resizeRec(ctx);
		if ( ctx.measure ) {
			
		}else{
			if( sinput == null ){
				sinput = new h2d.Interactive(0, 0, this);
				#if debug
				sinput.name = "comp.Scroll sinput";
				#end
				sinput.cursor = Default;
				sinput.onPush = onPush;
				sinput.onRelease = onRelease;
				sinput.onMove = onMove;
				sinput.onWheel = onMouseWheel;
				sinput.propagateEvents = true;
			//	sinput.blockEvents = false;
			}
			sinput.width = width - (style.marginLeft + style.marginRight);
			sinput.height = height - (style.marginTop + style.marginBottom);
		}
	}
	

}
