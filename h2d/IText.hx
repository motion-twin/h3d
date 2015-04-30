package h2d;


interface IText {
	public var text(default, set) : String;
	
	public var textColor(default, set) : Int;
	public var maxWidth(default, set) : Null<Float>;
	
	//public var dropShadow : { dx : Float, dy : Float, color : Int, alpha : Float };

	public var textWidth(get, null) : Int;
	public var textHeight(get, null) : Int;
	public var textAlign(default, set) : h2d.Text.Align;
	public var letterSpacing(default,set) : Int;
	public var lineSpacing(default,set) : Int;
}