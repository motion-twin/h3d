package h2d.comp;
import h2d.css.Defs.TileStyle;


class Image extends Interactive {
 
	public var tile(default,set) : TileStyle;
	
	public function new(?parent) {
		super("img",parent);
	}
	
	function set_tile(tile) {
		needRebuild = true;
		return this.tile = tile;
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
	
}