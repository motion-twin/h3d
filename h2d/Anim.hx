package h2d;

class Anim extends Drawable {

	public var frames : Array<Tile>;
	public var currentFrame : Float;
	public var speed : Float;
	public var loop : Bool = true;
	
	/**
	 * Allow animations creation
	 * @param	?frames array of tile to use as frames
	 * @param	?speed play speed in frames per second
	 * @param  ?sh, optionnal shader for shader sharing
	 * Passing in a similar shader ( same constants will vastly improve performances
	 */
	public function new( ?frames : Array<h2d.Tile>, ?speed:Float, ?sh, ?parent ) {
		super(parent,sh);
		this.frames = frames == null ? [] : frames;
		this.currentFrame = 0;
		this.speed = speed == null ? 15 : speed;
	}
	
	
	
	public function play( frames ) {
		this.frames = frames;
		this.currentFrame = 0;
	}

	public dynamic function onAnimEnd() {
	}

	override function getBoundsRec( relativeTo, out ) {
		super.getBoundsRec(relativeTo, out);
		var tile = getFrame();
		if( tile != null ) addBounds(relativeTo, out, tile.dx, tile.dy, tile.width, tile.height);
	}

	override function sync( ctx : RenderContext ) {
		super.sync(ctx);
		var prev = currentFrame;
		currentFrame += speed * ctx.elapsedTime;
		if( currentFrame < frames.length )
			return;
		if( loop ) {
			currentFrame %= frames.length;
			onAnimEnd();
		} else if( currentFrame >= frames.length ) {
			currentFrame = frames.length;
			if( currentFrame != prev ) onAnimEnd();
		}
	}

	public function getFrame() {
		var i = Std.int(currentFrame);
		if( i == frames.length ) i--;
		return frames[i];
	}

	override function draw( ctx : RenderContext ) {
		var tile = getFrame();
		
		#if noEmit
		drawTile(ctx.engine, tile);	
		#else
		if ( isExoticShader() )
			drawTile(ctx.engine, tile);	
		else 
			emitTile(ctx, tile);
		#end
	}
	
}