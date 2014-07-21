package h2d;

import h2d.col.Bounds;

/**
 * Stores the number of childs sprites in each array indexing layers
 * the nth layer cell stores the beginnning of n+1 layer ( brainfuck )
 * ex 
 * if layer 0 has 3 sprite
 * if layer 1 has 4 sprite
 * you will have [4,7]
 */
class Layers extends Sprite {
	
	// the per-layer insert position
	public var layers(default,null) : Array<Int>;
	public var layerCount(default,null) : Int;
	
	public function new(?parent) {
		super(parent);
		layers = [];
		layerCount = 0;
	}
	
	public override function getMyBounds() : Bounds {
		return null;
	}
	
	public function getLayer(s:Sprite) {
		var idx = getChildIndex(s);
		var i = 0;
		while (idx > 0 ) {
			idx -= layers[i++];
		}
		return i-1;
	}
	
	public inline function getLayerStart(layer:Int) : Int {
		return layers[layer-1];
	}
	
	/**
	 * how many sprites is in this layer
	 */
	public  inline function getLayerCount(layer:Int) : Int {
		if ( layer == layerCount )  
			return numChildren - layers[layer - 1];
		else 
			return layers[layer] - layers[layer - 1];
	}

	/**
	 * Add on the layer 0 (Bottom)
	 * @param	s
	 */
	override function addChild(s:Sprite) {
		addChildAt(s, 0);
	}
	
	public inline function add(s, layer) {
		return addChildAt(s, layer);
	}
	
	public function clearLayer( layer : Int ) {
		var start = getLayerStart(layer);
		var idx = start + getLayerCount(layer);
		while ( idx-- > start )
			removeChildAt ( idx );
	}
	
	override function addChildAt( s : Sprite, layer : Int ) {
		if( s.parent == this ) {
			var old = s.allocated;
			s.allocated = false;
			removeChild(s);
			s.allocated = old;
		}
		// new layer
		while( layer >= layerCount )
			layers[layerCount++] = childs.length;
		super.addChildAt(s,layers[layer]);
		for( i in layer...layerCount )
			layers[i]++;
	}
	
	function removeChildAt( i:Int ) {
		var s = childs[i];
		childs.splice(i, 1);
		if( s.allocated ) s.onDelete();
		s.parent = null;
		var k = layerCount - 1;
		while( k >= 0 && layers[k] > i ) {
			layers[k]--;
			k--;
		}
	}
	
	override function removeChild( s : Sprite ) {
		for( i in 0...childs.length ) {
			if( childs[i] == s ) {
				removeChildAt(i);
				return;
			}
		}
	}
	
	public function under( s : Sprite ) {
		for( i in 0...childs.length )
			if( childs[i] == s ) {
				var pos = 0;
				for( l in layers )
					if( l > i )
						break;
					else
						pos = l;
				var p = i;
				while( p > pos ) {
					childs[p] = childs[p - 1];
					p--;
				}
				childs[pos] = s;
				break;
			}
	}
	
	public function over( s : Sprite ) {
		for( i in 0...childs.length )
			if( childs[i] == s ) {
				for( l in layers )
					if( l > i ) {
						for( p in i...l-1 )
							childs[p] = childs[p + 1];
						childs[l - 1] = s;
						break;
					}
				break;
			}
	}
	
	public function ysort( layer : Int = 0) {
		if( layer >= layerCount ) return;
		var start = layer == 0 ? 0 : layers[layer - 1];
		var max = layers[layer];
		if( start == max )
			return;
		var pos = start;
		var ymax = childs[pos++].y;
		while( pos < max ) {
			var c = childs[pos];
			if( c.y < ymax ) {
				var p = pos - 1;
				while( p >= start ) {
					var c2 = childs[p];
					if( c.y >= c2.y ) break;
					childs[p + 1] = c2;
					p--;
				}
				childs[p + 1] = c;
			} else
				ymax = c.y;
			pos++;
		}
	}

	
}