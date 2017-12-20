package hxd.snd.effect;

// I3DL reverb

class Reverb extends Effect {
	public var room              (default, set) : Float; // [-10000 0] mb
	public var roomHF            (default, set) : Float; // [-10000, 0] mb
	public var roomRolloffFactor (default, set) : Float; // [0.0, 10.0]
	public var decayTime         (default, set) : Float; // [0.1, 20.0] s
	public var decayHFRatio      (default, set) : Float; // [0.1, 2.0]
	public var reflections       (default, set) : Float; // [-10000, 1000] mb
	public var reflectionsDelay  (default, set) : Float; // [0.0, 0.3] s
	public var reverb            (default, set) : Float; // [-10000, 2000] mb
	public var reverbDelay       (default, set) : Float; // [0.0, 0.1] s
	public var diffusion         (default, set) : Float; // [0.0, 100.0] %
	public var density           (default, set) : Float; // [0.0, 100.0] %
	public var hfReference       (default, set) : Float; // [20.0, 20000.0]

	inline function set_room(v)              { changed = true; return room = v; }
	inline function set_roomHF(v)            { changed = true; return roomHF = v; }
	inline function set_roomRolloffFactor(v) { changed = true; return roomRolloffFactor = v; }
	inline function set_decayTime(v)         { changed = true; return decayTime = v; }
	inline function set_decayHFRatio(v)      { changed = true; return decayHFRatio = v; }
	inline function set_reflections(v)       { changed = true; return reflections = v; }
	inline function set_reflectionsDelay(v)  { changed = true; return reflectionsDelay = v; }
	inline function set_reverb(v)            { changed = true; return reverb = v; }
	inline function set_reverbDelay(v)       { changed = true; return reverbDelay = v; }
	inline function set_diffusion(v)         { changed = true; return diffusion = v; }
	inline function set_density(v)           { changed = true; return density = v; }
	inline function set_hfReference(v)       { changed = true; return hfReference = v; }

	public function new(?preset : ReverbPreset) {
		super(Reverb);
		loadPreset(preset != null ? preset : ReverbPreset.DEFAULT);
	}

	public function loadPreset(preset : ReverbPreset) {
		room             = preset.room;
		roomHF           = preset.roomHF;
		decayTime        = preset.decayTime;
		decayHFRatio     = preset.decayHFRatio;
		reflections      = preset.reflections;
		reflectionsDelay = preset.reflectionsDelay;
		reverb           = preset.reverb;
		reverbDelay      = preset.reverbDelay;
		diffusion        = preset.diffusion;
		density          = preset.density;
		hfReference      = preset.hfReference;
	}

	override function applyAudibleGainModifier(v : Float) {
		//return v + gain * Math.max(reflectionsGain, lateReverbGain);
		return v;
	}
}