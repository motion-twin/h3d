package h2d;

/**
 * Allows to mask content 
 * The content is masked from the top left 
 * 
 * width and height are the regions of masking
 * offset can be used to control the origin offset
 * 
 * Mask doesn't behave well on translated scene
 */
class Mask extends Sprite {

	public var offsetX : Float = 0.0;
	public var offsetY : Float = 0.0;
	
	public var innerWidth : Float;
	public var innerHeight : Float;
	
	public override function set_width(v) {
		return innerWidth = v;
	}
	
	public override function set_height(v) : Float {
		return innerHeight = v;
	}

	public override function get_width() : Float {
		return innerWidth;
	}
	
	public override function get_height() : Float {
		return innerHeight;
	}
	
	public function new(width = 0.0, height = 0.0, ?parent) {
		super(parent);
		this.width = width;	
		this.height = height;
	}

	override function getBoundsRec( relativeTo, out ) {
		super.getBoundsRec(relativeTo, out);
		var xMin = out.xMin, yMin = out.yMin, xMax = out.xMax, yMax = out.yMax;
		out.empty();
		addBounds(relativeTo, out, 0, 0, width, height);
		if( xMin > out.xMin ) out.xMin = xMin;
		if( yMin > out.yMin ) out.yMin = yMin;
		if( xMax < out.xMax ) out.xMax = xMax;
		if ( yMax < out.yMax ) out.yMax = yMax;
		
		out.translate( offsetX, offsetY );
	}

	override function drawRec( ctx : h2d.RenderContext ) {
		ctx.flush();
		
		var x1 = (absX + 1) * 0.5 * ctx.engine.width;
		var y1 = (1 - absY) * 0.5 * ctx.engine.height;

		var x2 = ((width * matA + height * matC + absX) + 1) * 0.5 * ctx.engine.width;
		var y2 = (1 - (width * matB + height * matD + absY)) * 0.5 * ctx.engine.height;
		
		x1 += offsetX;
		y1 += offsetY;
		
		x2 += offsetX;
		y2 += offsetY;

		var rz = ctx.engine.getRenderZone();
		ctx.engine.setRenderZone(Std.int(x1), Std.int(y1), Std.int(x2-x1), Std.int(y2-y1));
		super.drawRec(ctx);
		
		ctx.flush();
		
		if( rz!=null)	ctx.engine.setRenderZone(Std.int(rz.x), Std.int(rz.y), Std.int(rz.z), Std.int(rz.w));
		else 			ctx.engine.setRenderZone();
	}

}