package hxd.snd.openal;

import hxd.snd.Driver;

#if hlopenal
typedef AL = openal.AL;
private typedef ALC          = openal.ALC;
private typedef ALSource     = openal.AL.Source;
private typedef ALBuffer     = openal.AL.Buffer;
private typedef ALDevice     = openal.ALC.Device;
private typedef ALContext    = openal.ALC.Context;
private typedef EFX          = openal.EFX;
private typedef ALFilter     = openal.EFX.Filter;
private typedef ALEffect     = openal.EFX.Effect;
private typedef ALEffectSlot = openal.EFX.EffectSlot;
#else
typedef AL = ALEmulator;
private typedef ALC          = ALEmulator.ALCEmulator;
private typedef ALSource     = ALEmulator.ALSource;
private typedef ALBuffer     = ALEmulator.ALBuffer;
private typedef ALDevice     = ALEmulator.ALDevice;
private typedef ALContext    = ALEmulator.ALContext;
private typedef EFX          = ALEmulator.EFXEmulator;
private typedef ALFilter     = Dynamic;
private typedef ALEffect     = Dynamic;
private typedef ALEffectSlot = Dynamic;
#end

typedef EffectHandle = Dynamic;

class SourceHandle {
	public var inst : ALSource;
	public var sampleOffset : Int;

	var nextAuxiliarySend     : Int;
	var freeAuxiliarySends    : Array<Int>;
	var effectToAuxiliarySend : Map<Effect, Int>;

	public function new() {
		nextAuxiliarySend = 0;
		freeAuxiliarySends = [];
		effectToAuxiliarySend = new Map();
	}

	public function acquireAuxiliarySend(effect : Effect) : Int {
		var send = freeAuxiliarySends.length > 0
			? freeAuxiliarySends.shift()
			: nextAuxiliarySend++;
		effectToAuxiliarySend.set(effect, send);
		return send;
	}

	public function releaseAuxiliarySend(effect : Effect) : Int {
		var send = effectToAuxiliarySend.get(effect);
		effectToAuxiliarySend.remove(effect);
		freeAuxiliarySends.push(send);
		return send;
	}
}

class BufferHandle {
	public var inst : ALBuffer;
	public var isEnd : Bool;
	public function new() { }
}

class EffectManager {
	var driver : DriverImpl;

	public function new(driver : DriverImpl) { 
		this.driver = driver;
	}

	public function enableEffect  (e : Effect) : Void {}
	public function updateEffect  (e : Effect) : Void {}
	public function disableEffect (e : Effect) : Void {}

	public function bindEffect    (e : Effect, source : SourceHandle) : Void {}
	public function applyEffect   (e : Effect, source : SourceHandle) : Void {}
	public function unbindEffect  (e : Effect, source : SourceHandle) : Void {}
}

class DriverImpl implements Driver {
	public var device   (default, null) : ALDevice;
	public var context  (default, null) : ALContext;
	public var maxAuxiliarySends(default, null) : Int;

	var tmpBytes : haxe.io.Bytes;
	var effectManagerMap : Map<EffectKind, EffectManager>;

	public function new() {
		tmpBytes = haxe.io.Bytes.alloc(4 * 3 * 2);
		device   = ALC.openDevice(null);
		context  = ALC.createContext(device, null);

		ALC.makeContextCurrent(context);
		ALC.loadExtensions(device);
		AL.loadExtensions();

		// query maximum number of auxiliary sends
		var bytes = getTmpBytes(4);
		ALC.getIntegerv(device, EFX.MAX_AUXILIARY_SENDS, 1, bytes);
		maxAuxiliarySends = bytes.getInt32(0);
		trace("maxAuxiliarySends = " + maxAuxiliarySends);

		effectManagerMap = new Map();
		effectManagerMap.set(LowPassFilter,  new LowPassFilterManager(this));
		effectManagerMap.set(Spatialization, new SpatializationManager(this));
		effectManagerMap.set(Pitch,          new PitchManager(this));
		effectManagerMap.set(Reverb,         new ReverbManager(this));
	}

	public function getTmpBytes(size) {
		if (tmpBytes.length < size) tmpBytes = haxe.io.Bytes.alloc(size);
		return tmpBytes;
	}

	public function setMasterVolume(value : Float) : Void {
		AL.listenerf(AL.GAIN, value);
	}

	public function setListenerParams(position : h3d.Vector, direction : h3d.Vector, up : h3d.Vector, ?velocity : h3d.Vector) : Void {
		AL.listener3f(AL.POSITION, -position.x, position.y, position.z);

		var bytes = getTmpBytes(24);
		bytes.setFloat(0,  -direction.x);
		bytes.setFloat(4,   direction.y);
		bytes.setFloat(8,   direction.z);

		bytes.setFloat(12, -up.x);
		bytes.setFloat(16,  up.y);
		bytes.setFloat(20,  up.z);

		AL.listenerfv(AL.ORIENTATION, tmpBytes);

		if (velocity != null)
			AL.listener3f(AL.VELOCITY, -velocity.x, velocity.y, velocity.z);
	}

	public function createSource() : SourceHandle {
		var source = new SourceHandle();
		var bytes = getTmpBytes(4);
		AL.genSources(1, bytes);
		if (AL.getError() != AL.NO_ERROR) throw "could not create source";
		source.inst = ALSource.ofInt(bytes.getInt32(0));
		AL.sourcei(source.inst, AL.SOURCE_RELATIVE, AL.TRUE);
		return source;
	}

	public function destroySource(source : SourceHandle) : Void {
		var bytes = getTmpBytes(4);
		bytes.setInt32(0, source.inst.toInt());
		AL.deleteSources(1, bytes);
	}

	public function playSource(source : SourceHandle) : Void {
		AL.sourcePlay(source.inst);
	}

	public function stopSource(source : SourceHandle) : Void {
		AL.sourceStop(source.inst);
	}

	public function getSourceState(source : SourceHandle) : SourceState {
		return switch (AL.getSourcei(source.inst, AL.SOURCE_STATE)) {
			case AL.STOPPED : Stopped;
			case AL.PLAYING : Playing;
			default : Unhandled;
		};
	}

	public function setSourceVolume(source : SourceHandle, value : Float) : Void {
		AL.sourcef(source.inst, AL.GAIN, value);
	}

	public function createBuffer() : BufferHandle {
		var buffer = new BufferHandle();
		var bytes = getTmpBytes(4);
		AL.genBuffers(1, bytes);
		buffer.inst = ALBuffer.ofInt(bytes.getInt32(0));
		return buffer;
	}

	public function destroyBuffer(buffer : BufferHandle) : Void {
		var bytes = getTmpBytes(4);
		bytes.setInt32(0, buffer.inst.toInt());
		AL.deleteBuffers(1, bytes);
	}
	
	public function setBufferData(buffer : BufferHandle, data : haxe.io.Bytes, size : Int, format : Data.SampleFormat, channelCount : Int, samplingRate : Int) : Void {
		var alFormat = switch (format) {
			case UI8 : channelCount == 1 ? AL.FORMAT_MONO8  : AL.FORMAT_STEREO8;
			case I16 : channelCount == 1 ? AL.FORMAT_MONO16 : AL.FORMAT_STEREO16;
			case F32 : channelCount == 1 ? AL.FORMAT_MONO16 : AL.FORMAT_STEREO16;
		}
		AL.bufferData(buffer.inst, alFormat, data, size, samplingRate);
	}

	public function getPlayedSampleCount(source : SourceHandle) : Int {
		return source.sampleOffset + AL.getSourcei(source.inst, AL.SAMPLE_OFFSET);
	}

	public function getProcessedBuffers(source : SourceHandle) : Int {
		return AL.getSourcei(source.inst, AL.BUFFERS_PROCESSED);
	}
	
	public function queueBuffer(source : SourceHandle, buffer : BufferHandle, sampleStart : Int, endOfStream : Bool) : Void {
		var bytes = getTmpBytes(4);
		bytes.setInt32(0, buffer.inst.toInt());
		AL.sourceQueueBuffers(source.inst, 1, bytes);

		if (AL.getError() != AL.NO_ERROR)
			throw "Failed to queue buffers : format differs";

		if (AL.getSourcei(source.inst, AL.SOURCE_STATE) == AL.STOPPED) {
			if (sampleStart > 0) {
				AL.sourcei(source.inst, AL.SAMPLE_OFFSET, sampleStart);
				source.sampleOffset = -sampleStart;
			} else {
				source.sampleOffset = 0;
			}
		}
		buffer.isEnd = endOfStream;
	}
	
	public function unqueueBuffer(source : SourceHandle, buffer : BufferHandle) : Void {
		var bytes = getTmpBytes(4);
		bytes.setInt32(0, buffer.inst.toInt());
		AL.sourceUnqueueBuffers(source.inst, 1, bytes);

		var samples = Std.int(AL.getBufferi(buffer.inst, AL.SIZE) / AL.getBufferi(buffer.inst, AL.BITS) * 4);
		if (buffer.isEnd) source.sampleOffset = 0;
		else source.sampleOffset += samples;
	}
	
	public function preUpdate() : Void {

	}

	public function postUpdate() : Void {

	}
	
	public function dispose() : Void {
		ALC.makeContextCurrent(null);
		ALC.destroyContext(context);
		ALC.closeDevice(device);
	}

	public function enableEffect(e : Effect) : Void {
		var mng = effectManagerMap.get(e.kind);
		if (mng != null) mng.enableEffect(e);
	}

	public function updateEffect(e : Effect) : Void {
		var mng = effectManagerMap.get(e.kind);
		if (mng != null) mng.updateEffect(e);
	}

	public function disableEffect (e : Effect) : Void {
		var mng = effectManagerMap.get(e.kind);
		if (mng != null) mng.disableEffect(e);
	}

	public function bindEffect(e : Effect, source : SourceHandle) : Void {
		var mng = effectManagerMap.get(e.kind);
		if (mng != null) mng.bindEffect(e, source);
	}

	public function applyEffect(e : Effect, source : SourceHandle) : Void {
		var mng = effectManagerMap.get(e.kind);
		if (mng != null) mng.applyEffect(e, source);
	}

	public function unbindEffect(e : Effect, source : SourceHandle) : Void {
		var mng = effectManagerMap.get(e.kind);
		if (mng != null) mng.unbindEffect(e, source);
	}
}

@:access(hxd.snd.Effect)
class LowPassFilterManager extends EffectManager {
	override function enableEffect(e : Effect) : Void {
		var bytes = driver.getTmpBytes(4);
		EFX.genFilters(1, bytes);
		var handle = ALFilter.ofInt(bytes.getInt32(0));
		EFX.filteri(handle, EFX.FILTER_TYPE, EFX.FILTER_LOWPASS);
		e.handle = handle;
	}

	override function updateEffect(e : Effect) : Void {
		var e = Std.instance(e, hxd.snd.effect.LowPassFilter);
		EFX.filterf(e.handle, EFX.LOWPASS_GAIN,   e.gain);
		EFX.filterf(e.handle, EFX.LOWPASS_GAINHF, e.gainHF);
	}

	override function disableEffect(e : Effect) : Void {
		var bytes = driver.getTmpBytes(4);
		bytes.setInt32(0, e.handle);
		EFX.deleteFilters(1, bytes);
	}

	override function bindEffect(e : Effect, source : SourceHandle) : Void {
		AL.sourcei(source.inst, EFX.DIRECT_FILTER, e.handle);
	}

	override function applyEffect(e : Effect, source : SourceHandle) : Void {
		AL.sourcei(source.inst, EFX.DIRECT_FILTER, e.handle);
	}

	override function unbindEffect(e : Effect, source : SourceHandle) : Void {
		AL.sourcei(source.inst, EFX.DIRECT_FILTER, EFX.FILTER_NULL);
	}
}

class PitchManager extends EffectManager {
	override function applyEffect(e : Effect, source : SourceHandle) : Void {
		AL.sourcef(source.inst, AL.PITCH, Std.instance(e, hxd.snd.effect.Pitch).value);
	}

	override function unbindEffect(e : Effect, source : SourceHandle) : Void {
		AL.sourcef(source.inst, AL.PITCH, 1.);
	}
}

class SpatializationManager extends EffectManager {
	override function bindEffect(e : Effect, s : SourceHandle) : Void {
		AL.sourcei(s.inst,  AL.SOURCE_RELATIVE, AL.FALSE);
	}

	override function applyEffect(e : Effect, s : SourceHandle) : Void {
		var e = Std.instance(e, hxd.snd.effect.Spatialization);

		AL.source3f(s.inst, AL.POSITION,  -e.position.x,  e.position.y,  e.position.z);
		AL.source3f(s.inst, AL.VELOCITY,  -e.velocity.x,  e.velocity.y,  e.velocity.z);
		AL.source3f(s.inst, AL.DIRECTION, -e.direction.x, e.direction.y, e.direction.z);
		AL.sourcef(s.inst, AL.REFERENCE_DISTANCE, e.referenceDistance);
		AL.sourcef(s.inst, AL.ROLLOFF_FACTOR, e.rollOffFactor);
		AL.sourcef(s.inst, AL.MAX_DISTANCE, e.maxDistance == null ? 3.40282347e38 : (e.maxDistance:Float) );
	}

	override function unbindEffect(e : Effect, s : SourceHandle) : Void {
		AL.source3f(s.inst, AL.POSITION,  0, 0, 0);
		AL.source3f(s.inst, AL.VELOCITY,  0, 0, 0);
		AL.source3f(s.inst, AL.DIRECTION, 0, 0, 0);
		AL.sourcei (s.inst, AL.SOURCE_RELATIVE, AL.TRUE);
	}
}

class ALEffectHandle {
	public var inst : ALEffect;
	public var slot : ALEffectSlot;
	public function new() {}
}

@:access(hxd.snd.Effect)
class ReverbManager extends EffectManager {
	override function enableEffect(e : Effect) : Void {
		var handle = new ALEffectHandle();

		var bytes = driver.getTmpBytes(4);
		EFX.genEffects(1, bytes);
		handle.inst = ALEffect.ofInt(bytes.getInt32(0));
		if (AL.getError() != AL.NO_ERROR) throw "could not create an ALEffect instance";

		var bytes = driver.getTmpBytes(4);
		EFX.genAuxiliaryEffectSlots(1, bytes);
		handle.slot = ALEffectSlot.ofInt(bytes.getInt32(0));
		if (AL.getError() != AL.NO_ERROR) throw "could not create an ALEffectSlot instance";

		EFX.effecti(handle.inst, EFX.EFFECT_TYPE, EFX.EFFECT_REVERB);
		EFX.auxiliaryEffectSloti(handle.slot, EFX.EFFECTSLOT_EFFECT, handle.inst.toInt());

		trace("enable reverb, slot = " + handle.slot);

		e.handle = handle;
	}

	override function disableEffect(e : Effect) : Void {
		EFX.auxiliaryEffectSloti(e.handle.slot, EFX.EFFECTSLOT_EFFECT, EFX.EFFECTSLOT_NULL);

		var bytes = driver.getTmpBytes(4);
		bytes.setInt32(0, e.handle.slot);
		EFX.deleteAuxiliaryEffectSlots(1, bytes);

		var bytes = driver.getTmpBytes(4);
		bytes.setInt32(0, e.handle.inst);
		EFX.deleteEffects(1, bytes);

		trace("disable reverb, slot = " + e.handle.slot);
		e.handle = null;
	}

	override function updateEffect(e : Effect) : Void {
		var e = Std.instance(e, hxd.snd.effect.Reverb);
		e.retainTime = e.decayTime + e.reflectionsDelay + e.reverbDelay;
	}

	override function bindEffect(e : Effect, s : SourceHandle) : Void {
		var send = s.acquireAuxiliarySend(e);
		if (send + 1 >= driver.maxAuxiliarySends) throw "too many auxiliary sends";
		AL.source3i(s.inst, EFX.AUXILIARY_SEND_FILTER, e.handle.slot, send, EFX.FILTER_NULL);
		trace("bind source send " + send + " to effect slot " + e.handle.slot);
	}

	override function applyEffect(e : Effect, s : SourceHandle) : Void {

	}

	override function unbindEffect(e : Effect, s : SourceHandle) : Void {
		var send = s.releaseAuxiliarySend(e);
		AL.source3i(s.inst, EFX.AUXILIARY_SEND_FILTER, EFX.EFFECTSLOT_NULL, send, EFX.FILTER_NULL);
		trace("UNbind source send " + send + " to effect slot " + e.handle.slot);
	}
}

/*

// reverb

override function onAlloc() {
	super.onAlloc();
	EFX.effecti(instance, EFX.EFFECT_TYPE, EFX.EFFECT_REVERB);
}

override function apply(source : Driver.Source) {
	if (changed) {
		EFX.effectf(instance, EFX.REVERB_DENSITY,               density);
		EFX.effectf(instance, EFX.REVERB_DIFFUSION,             diffusion);
		EFX.effectf(instance, EFX.REVERB_GAIN,                  gain);
		EFX.effectf(instance, EFX.REVERB_GAINHF,                gainHF);
		EFX.effectf(instance, EFX.REVERB_DECAY_TIME,            decayTime);
		EFX.effectf(instance, EFX.REVERB_DECAY_HFRATIO,         decayHFRatio);
		EFX.effectf(instance, EFX.REVERB_REFLECTIONS_GAIN,      reflectionsGain);
		EFX.effectf(instance, EFX.REVERB_REFLECTIONS_DELAY,     reflectionsDelay);
		EFX.effectf(instance, EFX.REVERB_LATE_REVERB_GAIN,      lateReverbGain);
		EFX.effectf(instance, EFX.REVERB_LATE_REVERB_DELAY,     lateReverbDelay);
		EFX.effectf(instance, EFX.REVERB_AIR_ABSORPTION_GAINHF, airAbsorptionGainHF);
		EFX.effectf(instance, EFX.REVERB_ROOM_ROLLOFF_FACTOR,   roomRolloffFactor);
		EFX.effecti(instance, EFX.REVERB_DECAY_HFLIMIT,         decayHFLimit);

		slotRetainTime = decayTime + reflectionsDelay + lateReverbDelay;
	}
	super.apply(source);
}

*/