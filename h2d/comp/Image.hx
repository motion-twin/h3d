package h2d.comp;
import h2d.css.Defs.TileStyle;


class Image extends Interactive {
 
	public var tile(default,set) : TileStyle;
	
	public function new(?parent) {
		super("img", parent);
		hasInteraction = false;
	}
	
	function set_tile(tile:TileStyle) {
		needRebuild = true;
		return this.tile = tile;
	}
	
	public override function clone<T>(?s:T) : T{
		var t : Image = (s == null) ? new Image(parent) : cast s;
		super.clone(t);
		
		t.tile = tile.clone();
		
		return cast t;
	}
	
	override function evalStyle() {
		super.evalStyle();
		style.backgroundSize = Percent(100, 100);
		style.backgroundTile = tile;
	}
	
	override function resize( ctx : Context ) {
		if( bgBmp!=null && bgBmp.visible ){
			contentWidth = tile.nativeWidth;
			contentHeight = tile.nativeHeight;
		}
		super.resize(ctx);
	}
	
	public static function fromAssets(path:String,?p:h2d.comp.Component) {
		var ts = new TileStyle();
		ts.widthAsPercent = true; ts.w = 100;
		ts.heightAsPercent = true; ts.h = 100;
		ts.mode = Assets;
		ts.file = path;
		var img = new Image(p);
		img.tile = ts;
		ts.update = function(cmp) {
			var img : Image = cast cmp;
			var style = img.getStyle(false);
			if ( style.width == null )
				img.addStyleString("width:" + img.tile.nativeWidth + ";");
			if ( style.height == null )
				img.addStyleString("height:" + img.tile.nativeHeight+";");
		}
		return img;
	}
}