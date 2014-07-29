class Comps {
	
	var engine : h3d.Engine;
	var container : h2d.Sprite;
	var scene : h2d.Scene;
	var frame = 0;
	var inc = 1;
	var fps : h2d.comp.Label;

	function new() {

		engine = new h3d.Engine();
		engine.onReady = init;
		engine.init();
		// make sure that arial.ttf is inside the current class path (remove "true" to get errors)
		// emebedding the font will greatly improve visibility on flash (might be required on some targets)
		hxd.res.Embed.embedFont("arial.ttf", true);

		hxd.Key.initialize();
		hxd.Profiler.minLimit = -1;

		hxd.System.debugLevel = 1;

		flash.Lib.current.stage.addEventListener(flash.events.KeyboardEvent.KEY_UP, function(event) {
			if(event.keyCode == 27) {//back button
				event.stopImmediatePropagation();
				dump();
			}
		});

		hxd.Profiler.enable = false;

	}
	
	function init() {
		hxd.System.setLoop(update);
		scene = new h2d.Scene();

		container = new h2d.Sprite( scene );

		hxd.res.FontBuilder.getFont("Arial", 14);
		
		hxd.Profiler.begin("+ h2d.comp.Parser");
		var document = h2d.comp.Parser.fromHtml(hxd.res.Embed.getFileContent("components.html"),{ fmt : hxd.Math.fmt });
		hxd.Profiler.end("+ h2d.comp.Parser");
		container.addChild(document);
		fps = cast new h2d.comp.JQuery( document, "#fps" ).getComponents()[0];
		engine.onResized = function() document.setStyle(null);
	}

	function end(){
	}

	function dump(){
		trace("## "+frame+" ########################");
		trace( hxd.Profiler.dump(true) );

		#if cpp
		var driver : h3d.impl.GlDriver = cast engine.driver;
		trace( "shaderSwitch: "+driver.shaderSwitch+" textureSwitch: "+driver.textureSwitch );
		#end
		
		hxd.Profiler.clean();
	}
	
	function update() {
		hxd.Profiler.end("vbl");

		engine.render(scene);

		
		scene.checkEvents();

		/*
		container.x += inc;
		if( container.x > 200 || container.x < -200 )
			inc *= -1;
		*/

		frame++;

		if( frame%60 == 0 ){
			fps.text = Std.string( Math.round(engine.fps) );
			dump();
		}
			

		hxd.Profiler.begin("vbl");
	}
	
	static function main() {
		new Comps();
	}
	
}
