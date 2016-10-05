package h2d.renderer;

class Base
{
	var ctx : RenderContext;

	public function new() { }

	public function setContext( ctx : RenderContext ) {
		this.ctx = ctx;
	}

	public function process( s : h2d.Sprite ) { }
}