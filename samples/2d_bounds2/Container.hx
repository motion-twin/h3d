package ;

import h2d.Sprite;

/**
 * ...
 * @author Tipyx
 */

class Container extends Sprite
{

	public function new(?p) {
		super(p);
		
		var bmp = new h2d.Bitmap(h2d.Tile.fromColor(0xFF00FF00, 50, 50));
		bmp.x = -bmp.width / 2;
		bmp.y = -bmp.height / 2;
		this.addChild(bmp);
	}
	
	var spin = 0;
	public function update() {
		if( spin++ > 60){
		trace(this.mouseX);
		spin = 0;
		}
	}
}