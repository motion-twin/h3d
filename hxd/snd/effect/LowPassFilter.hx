package hxd.snd.effect;

class LowPassFilter extends hxd.snd.Effect {
	public var gain   : Float;
	public var gainHF : Float;

	public function new() {
		super(LowPassFilter);
		gain   = 1.0;
		gainHF = 1.0;
	}

	override function applyAudibleGainModifier(v : Float) {
		return v * gain;
	}
}