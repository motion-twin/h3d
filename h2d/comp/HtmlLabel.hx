package h2d.comp;

class HtmlLabel extends Component {
	
	var tf : h2d.HtmlText;
	
	public var text(default, set) : String;
	
	public function new(text, ?parent) {
		super("htmllabel",parent);
		tf = new h2d.HtmlText(null, this);
		this.text = text;
	}
	
	public override function clone<T>( ?c : T ) : T {
		var c : HtmlLabel = (c == null) ? new HtmlLabel(name, parent) : cast c;
		super.clone(c);
		c.text = text;
		return cast c;
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

	function get_text() {
		return tf.htmlText;
	}
	
	function set_text(t) {
		needRebuild = true;
		return text = t;
	}
	
	override function resize( ctx : Context ) {
		if( ctx.measure )
			htmlTextResize( tf, text, ctx );
		super.resize(ctx);
		if( !ctx.measure )
			processHtmlText(tf);
	}

	function htmlLetterSpacing( tf : h2d.HtmlText ) {
		if(style.letterSpacing!=null)
			tf.letterSpacing = style.letterSpacing;
	}
	
	function processHtmlText(tf:h2d.HtmlText) {
		if ( style == null ) return;
		
		htmlTextAlign(tf);
		htmlTextVAlign(tf);
		htmlTextColorTransform(tf);
		htmlLetterSpacing(tf);
		
		if( style.textPositionX!=null)
			tf.x += style.textPositionX;
		
		if( style.textPositionY!=null)
			tf.y += style.textPositionY;
	}
	
	inline function htmlTextVAlign( tf : h2d.HtmlText ) {
		if( style.height == null ) {
			tf.y = 0;
			return;
		}
		
		switch( style.textVAlign ) {
			case Top:		tf.y = 0;
			case Bottom:	tf.y = Std.int(getStyleHeight() - tf.textHeight);
			case Middle:	tf.y = Std.int((getStyleHeight() - tf.textHeight) * 0.5);
		}
	}
	
	inline function htmlTextAlign( tf : h2d.HtmlText ) {
		if( style.width == null ) {
			tf.x = 0;
			return;
		}
		switch( style.textAlign ) {
			case Left:	tf.x = 0;
			case Right:	tf.x = Std.int( getStyleWidth() - tf.textWidth);
			case Center:tf.x = Std.int((getStyleWidth() - tf.textWidth) * 0.5);
		}
	}
	
	inline 
	function jtmlLetterSpacing( tf : h2d.HtmlText ) {
		if(style.letterSpacing!=null)
			tf.letterSpacing = style.letterSpacing;
	}
	
	
	function htmlTextColorTransform( tf : h2d.HtmlText ) {
		if ( style.textColorTransform != null ) 
			tf.colorMatrix = makeColorTransformMatrix( style.textColorTransform,tf.colorMatrix );
		else 
			tf.colorMatrix = null;
			
		if( style.opacity != null )
			tf.alpha = style.opacity;
	}
	
	
	function htmlTextResize( tf : h2d.HtmlText, text : String, ctx : Context ){
		tf.font = getFont();
		tf.textColor = (tf.textColor&0xff000000) | (0x00ffffff&style.color);
		tf.htmlText = text;
		
		if ( style.width != null ) 
			tf.maxWidth = style.widthIsPercent ? parent.width * style.width : style.width;
		else
			tf.maxWidth = ctx.maxWidth;
		
		contentWidth = tf.textWidth;
		contentHeight = tf.textHeight;
	}
	

}
