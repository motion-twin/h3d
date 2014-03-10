
import flash.display.BitmapData;
import flash.geom.Matrix;
import flash.geom.Point;

import mt.deepnight.SpriteLibBitmap.BSprite;
import mt.deepnight.SpriteLibBitmap;
import mt.deepnight.assets.ShoeBox;

class Data{
	public static var slbCarPlayers : mt.deepnight.SpriteLibBitmap = null;
	public static var slbTerrain : mt.deepnight.SpriteLibBitmap = null;
	
	public static function create() {
		slbCarPlayers = ShoeBox.importXml("../assets/carPlayers.xml");
		slbTerrain = ShoeBox.importXml("../assets/terrain.xml");
	}
	
}