package h2d.comp;

class Interactive extends Component {
	
	public var hasInteraction : Bool;
	var input : h2d.Interactive;
	var needInput : Bool;
	var active : Bool;
	var activeRight : Bool;
	
	function new(kind,?parent) {
		super(kind,parent);

		needInput = kind!="box";
		hasInteraction = kind!="box";
		if( needInput )
			initInput();
	}

	public override function clone<T>( ?c : T ) : T  {
		var c : Interactive = (c == null) ? new Interactive(name,parent) : cast c;
		
		super.clone(c);
		
		c.needInput = needInput;
		c.active = active;
		c.activeRight = activeRight;
		c.hasInteraction = hasInteraction;
		
		return cast c;
	}
	
	function initInput(){
		input = new h2d.Interactive(0, 0, bgFill);
		input.enableRightButton = true;
		active = false;
		activeRight = false;
		input.onPush = function(e) {
			switch( e.button ) {
			case 0:
				active = true;
				removeClass(":hover");
				addClass(":clicked");
				onMouseDown();
			case 1:
				activeRight = true;
			}
		};
		input.onOver = function(_) {
			addClass(":hover");
			onMouseOver();
			#if false
			trace( this );
			trace( style );
			#end
		};
		input.onOut = function(_) {
			active = false;
			activeRight = false;
			removeClass(":hover");
			onMouseOut();
		};
		input.onRelease = function(e) {
			switch( e.button ) {
			case 0:
				if( active ) {
					active = false;
					removeClass(":clicked");
					addClass(":hover");
					onClick();
				}
				onMouseUp();
			case 1:
				if( activeRight ) {
					activeRight = false;
					onRightClick();
				}
			}
		};
	}
	
	function refitInput(ctx:Context) {
		//is it ok?
		input.x = 0;
		input.y = 0;
		
		input.width = width - (style.marginLeft + style.marginRight);
		input.height = height - (style.marginTop + style.marginBottom);
		input.visible = style.visibility &&  !hasClass(":disabled") && (hasInteraction || hasClass(":modal"));
		
		if ( ctx.curRz != null) {
			//var bnd = getBounds( ctx.scene );
			var tl = localToGlobal();
			var br = localToGlobal( new h2d.col.Point(input.width,input.height) );
			//trace( tl);
			
			var rzBound = new h2d.col.Bounds();
			rzBound.add4(ctx.curRz.x, ctx.curRz.y, ctx.curRz.z, ctx.curRz.w);
			
			var dx = (rzBound.x - tl.x);
			var dxMax = (rzBound.xMax - br.x );
			
			var dy = (rzBound.y - tl.y);
			var dyMax = (rzBound.yMax - br.y );
			
			if ( rzBound.x > tl.x) {
				input.x += dx;	
				input.width -= dx;
				
				tl = localToGlobal();
				br = localToGlobal( new h2d.col.Point(input.width,input.height) );
			}
			
			if ( rzBound.xMax < br.x ) {
				input.width += (rzBound.xMax - br.x);
			}
			
			if ( rzBound.y > tl.y) {
				input.y += dy;	
				input.height -= dy;
				
				tl = localToGlobal();
				br = localToGlobal( new h2d.col.Point(input.width,input.height) );
			}
			
			if ( rzBound.yMax < br.y ) {
				input.height += (rzBound.yMax - br.y);
			}
			
			if ( input.width < 0) input.width = 0;
			if ( input.height < 0) input.height = 0;
		}
		
	}
	override function resize( ctx : Context ) {
		super.resize(ctx);
		if( !ctx.measure ) {
			if( needInput ){
				if( input == null ) initInput();
				refitInput(ctx);
			}else if( input != null ){
				input.remove();
				input = null;
			}
		}
	}
	
	public dynamic function onMouseOver() {
	}

	public dynamic function onMouseOut() {
	}
	
	public dynamic function onMouseDown() {
	}

	public dynamic function onMouseUp() {
	}
	
	public dynamic function onClick() {
	}
	
	public dynamic function onRightClick() {
	}
	
}
