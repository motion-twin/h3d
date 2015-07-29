package h2d;

class HtmlText extends Drawable {

	public var font(default, set) : Font;
	public var htmlText(default, set) : String;
	public var textColor(default, set) : Int;
	
	public var textWidth(get, null) : Int;
	public var textHeight(get, null) : Int;
	
	public var letterSpacing : Int;
	public var lineSpacing:Int;
	public var maxWidth : Null<Float>;
	
	var glyphs : TileColorGroup;
	
	public function new( font : Font, ?parent ) {
		super(parent);
		this.font = font;
		htmlText = "";
		shader = glyphs.shader;
		textColor = 0xFFFFFF;
	}
	
	public inline function nbQuad() {
		return htmlText.length;
	}
	
	override function onAlloc() {
		super.onAlloc();
		if( htmlText != null ) initGlyphs(htmlText);
	}
	
	function set_font(f) {
		this.font = f;
		
		if ( glyphs != null ) {
			glyphs.remove();
			glyphs = null;
		}
			
		glyphs = new TileColorGroup(font == null ? null : font.tile, this);
		this.htmlText = htmlText;
		return f;
	}
	
	function set_htmlText(t) {
		this.htmlText = t == null ? "null" : t;
		if( allocated ) initGlyphs(t);
		return t;
	}
	
	var xPos : Int;
	var yPos : Int;
	var xMax : Int;
	
	function initGlyphs( text : String, rebuild = true, ?lines : Array<Int> ) {
		if( rebuild ) {
			glyphs.reset();
		}
		glyphs.setDefaultColor(textColor);
		xPos = 0;
		yPos = 0;
		xMax = 0;
		for( e in Xml.parse(text) )
			addNode(e, rebuild);
		var ret = new h2d.col.PointInt( xPos > xMax ? xPos : xMax, xPos > 0 ? yPos + (font.lineHeight + lineSpacing) : yPos );
		return ret;
	}
	
	static var utf8Text = new hxd.IntStack();
	
	public function splitText( text : String, leftMargin = 0 ) {
		if( maxWidth == null )
			return text;
		var lines = [], rest = text, restPos = 0;
		var x = leftMargin, prevChar = -1;
		
		utf8Text.reset();
		haxe.Utf8.iter( text,utf8Text.push );
		
		for( i in 0...utf8Text.length ) {
			var cc = utf8Text.unsafeGet(i);
			var e = font.getChar(cc);
			var newline = cc == '\n'.code;
			var esize = e.width + e.getKerningOffset(prevChar);
			if( font.charset.isBreakChar(cc) ) {
				var size = x + esize + letterSpacing;
				var k = i + 1, max = text.length;
				var prevChar = prevChar;
				while( size <= maxWidth && k < utf8Text.length ) {
					var cc =  utf8Text.unsafeGet(k++);
					if( font.charset.isSpace(cc) || cc == '\n'.code ) break;
					var e = font.getChar(cc);
					size += e.width + letterSpacing + e.getKerningOffset(prevChar);
					prevChar = cc;
				}
				if( size > maxWidth ) {
					newline = true;
					lines.push(text.substr(restPos, i - restPos));
					restPos = i;
					if( font.charset.isSpace(cc) ) {
						e = null;
						restPos++;
					}
				}
			}
			if( e != null )
				x += esize + letterSpacing;
			if( newline ) {
				x = 0;
				prevChar = -1;
			} else
				prevChar = cc;
		}
		if( restPos < text.length )
			lines.push(text.substr(restPos, text.length - restPos));
		return lines.join("\n");
	}
	
	function addNode( e : Xml, rebuild : Bool ) {
		if( e.nodeType == Xml.Element ) {
			var colorChanged = false;
			switch( e.nodeName.toLowerCase() ) {
			case "font":
				for( a in e.attributes() ) {
					var v = e.get(a);
					switch( a.toLowerCase() ) {
					case "color":
						colorChanged = true;
						glyphs.setDefaultColor(Std.parseInt("0x" + v.substr(1)));
					default:
					}
				}
			case "br":
				if( xPos > xMax ) xMax = xPos;
				xPos = 0;
				yPos += font.lineHeight + lineSpacing;
			
			default:
			}
			for( child in e )
				addNode(child, rebuild);
			if( colorChanged )
				glyphs.setDefaultColor(textColor);
		} else {
			var t = splitText(e.nodeValue.split("\n").join(" "), xPos);
			var prevChar = -1;
			for( i in 0...haxe.Utf8.length(t) ) {
				var cc = haxe.Utf8.charCodeAt( t,i);
				if( cc == "\n".code ) {
					xPos = 0;
					yPos += font.lineHeight + lineSpacing;
					prevChar = -1;
					continue;
				}
				var e = font.getChar(cc);
				xPos += e.getKerningOffset(prevChar);
				if( rebuild ) glyphs.add(xPos, yPos, e.t);
				xPos += e.width + letterSpacing;
				prevChar = cc;
			}
		}
	}
	
	var tHeight : Null<Int> = null;
	function get_textHeight() : Int {
		if ( tHeight != null) return tHeight;
		var r = initGlyphs(htmlText, false);
		tWidth = r.x;
		tHeight = r.y;
		return tHeight;
	}

	var tWidth : Null<Int> = null;
	function get_textWidth() : Int {
		if ( tWidth != null) return tWidth;
		var r = initGlyphs(htmlText, false);
		tWidth = r.x;
		tHeight = r.y;
		return tWidth;
	}
	
	function set_textColor(c) {
		if( textColor != c ) {
			this.textColor = c;
			if( allocated && htmlText != "" ) initGlyphs(htmlText);
		}
		return c;
	}

}