package h2d.comp;

class Button extends Interactive {
	
	var tf : h2d.Text;
	
	public var text(default, set) : String;
	
	public function new(text, ?parent) {
		super("button",parent);
		tf = new h2d.Text(null, this);
		tf.filter = true;
		this.text = text;
	}

	function get_text() {
		return tf.text;
	}
	
	function applyTextTransform() {
		var t = text;
		if( style!=null)
		switch( style.textTransform ) {
			default:
			case Uppercase: t = t.toUpperCase();
			case Lowercase: t = t.toLowerCase();
			case Capitalize: t =  t.substr(0,1).toUpperCase() + t.substr(1).toLowerCase();
		}
		
		if ( t != text )
			text = t;
	}
	
	override function evalStyle() {
		super.evalStyle();
		applyTextTransform();
	}
	
	function set_text(t:String) {
		needRebuild = true;
		return text = t;
	}
	
	override function resize( ctx : Context ) {
		if( ctx.measure )
			textResize( tf, text, ctx );
		super.resize(ctx);
		if( !ctx.measure )
			processText(tf);
		
	}
	
}
