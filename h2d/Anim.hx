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
	
	override function sync( ctx : RenderContext ) {
		currentFrame += speed * ctx.elapsedTime;
		if( currentFrame < frames.length )
			return;
		if( loop )
			currentFrame %= frames.length;
		else if( currentFrame >= frames.length )
			currentFrame = frames.length - 0.00001;
		onAnimEnd();
	}

	public function getFrame() {
		return frames[Std.int(currentFrame)];
	}
	
	override function getMyBounds() : h2d.col.Bounds {
		var tile = getFrame();
		var m = getPixSpaceMatrix(tile);
		var bounds = h2d.col.Bounds.fromValues(0,0, tile.width,tile.height);
		bounds.transform( m );
		return bounds;
	}
	
	override function draw( ctx : RenderContext ) {
		var t = getFrame();
		
		drawTile(ctx.engine, t);
		/*
		if ( t != null )
			if ( isExoticShader() ){
				ctx.flush();
				drawTile(ctx.engine, t);	
			}
			else 
				emitTile(ctx, t);
		*/
	}
	
}