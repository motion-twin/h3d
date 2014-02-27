package h2d;

class Anim extends Drawable {

	public var frames : Array<Tile>;
	public var currentFrame : Float;
	public var speed : Float;
	public var loop : Bool = true;
	
	/**
	 * Allow animations creation
	 * @param	?frames array of tile to use as frames
	 * @param	?speed play speed
	 * @param  ?sh, optionnal shader for shader sharing
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
	
	override function sync( ctx : RenderContext ) {
		currentFrame += speed * ctx.elapsedTime;
		if( loop )
			currentFrame %= frames.length;
		else if( currentFrame >= frames.length )
			currentFrame = frames.length - 0.00001;
	}
	
	public function getFrame() {
		return frames[Std.int(currentFrame)];
	}
	
	override function draw( ctx : RenderContext ) {
		var t = getFrame();
		if( t != null ) drawTile(ctx.engine,t);
	}
	
}