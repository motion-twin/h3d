class Demo extends hxd.App
{
	var bg : h2d.Drawable;
	var ellapsed : Float;
	
	override function init() 
	{
		ellapsed = 0;
		
		bg = new h2d.Bitmap(h2d.Tile.fromAssets("assets/bg.png"), s2d);
		bg.displacementMap = h2d.Tile.fromAssets("assets/dismap.png");
	}
	
	override function update(dt:Float) 
	{
		ellapsed += dt;
		
		bg.displacementPos = new h3d.Vector(
			s2d.mouseX - (bg.displacementMap.width / 2), 
			s2d.mouseY - (bg.displacementMap.height / 2));
		
		// décallage par rapport à la taille du drawable (-0.5 -> 0.5 max)
		bg.displacementAmount = Math.cos(ellapsed/2) / 50;
			
		super.update(dt);
	}
	
	static function main() {
		new Demo();
	}
}
