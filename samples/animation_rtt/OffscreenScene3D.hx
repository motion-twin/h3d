
class OffscreenScene3D extends h3d.scene.Scene {
	var wantedWith : Int;
	var wantedHeight : Int;
	
	public function new(w,h) {
		super();
		wantedWith = w;
		wantedHeight = h;
	}
	
	public function renderOffscreen( target : h2d.Tile ) {
		var engine = h3d.Engine.getCurrent();
		
		var tw = hxd.Math.nextPow2(wantedWith);
		var th = hxd.Math.nextPow2(wantedHeight);
			
		if( target == null ) {
			var tex = new h3d.mat.Texture(tw, th,false,true);
			target = new h2d.Tile(tex, 0, 0, tw, th);
			
			target.scaleToSize(wantedWith, wantedHeight);
			
			#if cpp 
			target.targetFlipY();
			#end
		}
		
		var ow = engine.width;
		var oh = engine.height;
		
		engine.resize( tw, th);
		
		autoResize = false;
		camera.screenRatio = wantedWith/wantedHeight;
		camera.update();
		
		var oc = engine.triggerClear;
		engine.triggerClear = true;
		engine.begin();
		
		engine.setRenderZone(target.x, target.y, tw, th);
		
		var tx = target.getTexture();
		engine.setTarget(tx, true);
		
		render(engine);
		
		posChanged = true;
		engine.setTarget(null,false,null);
		engine.setRenderZone();
		engine.end();
		engine.triggerClear = oc;
		
		engine.resize(ow, oh);
		
		return target;
	}
	
}