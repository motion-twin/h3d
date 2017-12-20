package hxd.snd.effect;

class Pitch extends hxd.snd.Effect {
	public var value (default, set) : Float;
	
	inline function set_value(v) {
		changed = true;
		return value = v;
	}
	
	public function new(value = 1.0) {
		super(Pitch);
		this.value =  value;
	}
}