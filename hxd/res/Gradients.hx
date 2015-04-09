package hxd.res;

class Gradients extends Resource {
	public function toTextureMap(resolution = 256) : Map<String, h3d.mat.Texture> {
		var map  = new Map<String, h3d.mat.Texture>();
		var data = new hxd.fmt.grd.Reader(new FileInput(entry)).read();
		
		for (d in data) {
			var colors = new Array<{value : h3d.Vector, loc : Int}>();
			
			{	// preprocess gradient data
				for (cs in d.gradientStops) {
					var color : h3d.Vector;
					switch(cs.colorStop.color) {
						case RGB(r, g, b): color = new h3d.Vector(r / 255, g / 255, b / 255);
						case HSB(h, s, b): color = HSVtoRGB(h, s / 100, b / 100);
						default : throw "unhandled color type";
					}
					color.w = cs.opacity / 100;
					colors.push({value : color, loc : Std.int((resolution-1) * cs.colorStop.location / d.interpolation)});
				}
				colors.sort(function(a, b) { return a.loc - b.loc; } );
				
				if (colors[0].loc > 0)
					colors.unshift( { value : colors[0].value, loc : 0 } );
				if (colors[colors.length - 1].loc < resolution - 1)
					colors.push( { value : colors[colors.length-1].value, loc : resolution-1 } );
			}
			
			{	// create gradient texture
				var bmp = new hxd.BitmapData(resolution, 1);
				bmp.lock();
				
				var pi = 0; // pixel index
				var ci = 0; // color index
				var tmpCol = new h3d.Vector();
				
				while (pi < resolution) {
					var prevLoc = colors[ci    ].loc;
					var nextLoc = colors[ci + 1].loc;
					
					var prevCol = colors[ci    ].value;
					var nextCol = colors[ci + 1].value;
					
					while ( pi <= nextLoc ) {
						tmpCol.lerp(prevCol, nextCol, (pi - prevLoc) / (nextLoc - prevLoc));
						bmp.setPixel(pi++, 0, tmpCol.toColor());
					}
					++ci;
				}
				bmp.unlock();
				map.set(d.name, h3d.mat.Texture.fromBitmap(bmp));
			}
		}
		return map;
	}
	
	function HSVtoRGB(h : Float, s : Float, v : Float) : h3d.Vector
	{
		var i : Int;
		var f : Float; var p : Float; var q : Float; var t : Float;
		if( s == 0 )
			return new h3d.Vector(v, v, v);
		h /= 60;
		i = Math.floor( h );
		f = h - i;
		p = v * ( 1 - s );
		q = v * ( 1 - s * f );
		t = v * ( 1 - s * ( 1 - f ) );
		switch( i ) {
			case 0 : return new h3d.Vector(v, t, p);
			case 1 : return new h3d.Vector(q, v, p);
			case 2 : return new h3d.Vector(p, v, t);
			case 3 : return new h3d.Vector(p, q, v);
			case 4 : return new h3d.Vector(t, p, v);
			default: return new h3d.Vector(v, p, q);
		}
	}
}