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

	function initInput(){
		input = new h2d.Interactive(0, 0, bgFill);
		input.enableRightButton = true;
		active = false;
		activeRight = false;
		input.onPush = function(e) {
			switch( e.button ) {
			case 0:
				active = true;
				onMouseDown();
			case 1:
				activeRight = true;
			}
		};
		input.onOver = function(_) {
			addClass(":hover");
			onMouseOver();
			
			#if debug
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
	
	override function resize( ctx : Context ) {
		super.resize(ctx);
		if( !ctx.measure ) {
			if( needInput ){
				if( input == null )
					initInput();
				input.cursor = hasInteraction ? Button : Default;
				input.width = width - (style.marginLeft + style.marginRight);
				input.height = height - (style.marginTop + style.marginBottom);
				input.visible = !hasClass(":disabled");
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
