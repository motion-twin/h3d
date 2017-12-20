package hxd.snd.effect;

class LowPassFilter extends hxd.snd.Effect {
	public var gain   (default, set) : Float;
	public var gainHF (default, set) : Float;

	inline function set_gain(v)   { changed = true; return gain = v; }
	inline function set_gainHF(v) { changed = true; return gainHF = v; }

	public function new() {
		super(LowPassFilter);
		gain   = 1.0;
		gainHF = 1.0;
	}

	override function applyAudibleGainModifier(v : Float) {
		return v * gain;
	}
}