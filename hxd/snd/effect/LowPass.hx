package hxd.snd.effect;

class LowPass extends hxd.snd.Effect {
	public var gain   : Float;
	public var gainHF : Float;

	public function new() {
		super("lowpass");
		gain   = 1.0;
		gainHF = 1.0;
	}

	override function applyAudibleGainModifier(v : Float) {
		return v * gain;
	}
}