package hxd.snd.openal;

import hxd.snd.Driver;

#if hlopenal
typedef AL = openal.AL;
private typedef ALC       = openal.ALC;
private typedef ALSource  = openal.AL.Source;
private typedef ALBuffer  = openal.AL.Buffer;
private typedef ALDevice  = openal.ALC.Device;
private typedef ALContext = openal.ALC.Context;
private typedef EFX       = openal.EFX;
private typedef ALEffect  = openal.EFX.Effect;
private typedef ALFilter  = openal.EFX.Filter;
#else
typedef AL = ALEmulator;
private typedef ALC       = ALEmulator.ALCEmulator;
private typedef ALSource  = ALEmulator.ALSource;
private typedef ALBuffer  = ALEmulator.ALBuffer;
private typedef ALDevice  = ALEmulator.ALDevice;
private typedef ALContext = ALEmulator.ALContext;
private typedef EFX       = ALEmulator.EFXEmulator;
private typedef ALEffect  = Dynamic;
private typedef ALFilter  = Dynamic;
#end

typedef SourceHandle = ALSource;
typedef BufferHandle = ALBuffer;
typedef EffectHandle = Dynamic;

class DriverImpl implements Driver {

	var tmpBytes : haxe.io.Bytes;
	var device   : ALDevice;
	var context  : ALContext;

	public function new() {
		tmpBytes = haxe.io.Bytes.alloc(4 * 3 * 2);
		device   = ALC.openDevice(null);
		context  = ALC.createContext(device, null);
		ALC.makeContextCurrent(context);
		ALC.loadExtensions(device);
		AL.loadExtensions();
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
		var bytes = getTmpBytes(4);
		AL.genSources(1, bytes);
		var s = ALSource.ofInt(bytes.getInt32(0));
		AL.sourcei(s, AL.SOURCE_RELATIVE, AL.TRUE);
		return s;
	}

	public function destroySource(source : SourceHandle) : Void {
		var bytes = getTmpBytes(4);
		bytes.setInt32(0, source.toInt());
		AL.deleteSources(1, bytes);
	}

	public function playSource(source : SourceHandle) : Void {
		AL.sourcePlay(source);
	}

	public function stopSource(source : SourceHandle) : Void {
		AL.sourceStop(source);
	}

	public function getSourceState(source : SourceHandle) : SourceState {
		return switch (AL.getSourcei(source, AL.SOURCE_STATE)) {
			case AL.STOPPED : Stopped;
			case AL.PLAYING : Playing;
			default : Unhandled;
		};
	}

	public function setSourcePosition(source : SourceHandle, value : Float) : Void {
		AL.sourcef(source, AL.SEC_OFFSET, value);
	}

	public function setSourceVolume(source : SourceHandle, value : Float) : Void {
		AL.sourcef(source, AL.GAIN, value);
	}

	public function setSourceLooping(source : SourceHandle, value : Bool) : Void {
		AL.sourcei(source, AL.LOOPING, value ? AL.TRUE : AL.FALSE);
	}

	public function getSourcePosition(source : SourceHandle) : Float {
		return AL.getSourcef(source, AL.SEC_OFFSET);
	}
	
	public function createBuffer() : BufferHandle {
		var bytes = getTmpBytes(4);
		AL.genBuffers(1, bytes);
		return ALBuffer.ofInt(bytes.getInt32(0));
	}

	public function destroyBuffer(buffer : BufferHandle) : Void {
		var bytes = getTmpBytes(4);
		bytes.setInt32(0, buffer.toInt());
		AL.deleteBuffers(1, bytes);
	}
	
	public function setBufferData(buffer : BufferHandle, data : haxe.io.Bytes, size : Int, format : Data.SampleFormat, channelCount : Int, samplingRate : Int) : Void {
		var alFormat = switch (format) {
			case UI8 : channelCount == 1 ? AL.FORMAT_MONO8  : AL.FORMAT_STEREO8;
			case I16 : channelCount == 1 ? AL.FORMAT_MONO16 : AL.FORMAT_STEREO16;
			case F32 : channelCount == 1 ? AL.FORMAT_MONO16 : AL.FORMAT_STEREO16;
		}
		AL.bufferData(buffer, alFormat, data, size, samplingRate);
	}

	public function getProcessedBuffers(source : SourceHandle) : Int {
		return AL.getSourcei(source, AL.BUFFERS_PROCESSED);
	}
	
	public function setSourceBuffer(source : SourceHandle, buffer : BufferHandle) : Void {
		AL.sourcei(source, AL.BUFFER, buffer.toInt());
	}

	public function removeSourceBuffer(source : SourceHandle) : Void {
		AL.sourcei(source, AL.BUFFER, AL.NONE);
	}
	
	public function queueBuffer(source : SourceHandle, buffer : BufferHandle) : Void {
		var bytes = getTmpBytes(4);
		bytes.setInt32(0, buffer.toInt());
		AL.sourceQueueBuffers(source, 1, bytes);
	}
	
	public function unqueueBuffer(source : SourceHandle, buffer : BufferHandle) : Void {
		var bytes = getTmpBytes(4);
		bytes.setInt32(0, buffer.toInt());
		AL.sourceUnqueueBuffers(source, 1, bytes);
	}
	
	public function update() : Void {

	}
	
	public function dispose() : Void {
		ALC.makeContextCurrent(null);
		ALC.destroyContext(context);
		ALC.closeDevice(device);
	}

	function getTmpBytes(size) {
		if (tmpBytes.length < size) tmpBytes = haxe.io.Bytes.alloc(size);
		return tmpBytes;
	}

	public function createEffect(e : Effect) {
		trace("create effect  : " + e.kind); 
		switch(e.kind) {
			case "lowpass_filter" :
				var bytes = getTmpBytes(4);
				EFX.genFilters(1, bytes);
				var handle = ALFilter.ofInt(bytes.getInt32(0));
				EFX.filteri(handle, EFX.FILTER_TYPE, EFX.FILTER_LOWPASS);
				e.handle = handle;
			default : 
				null;
		}
	}
		
	public function destroyEffect (e : Effect) { 
		trace("destroy effect : " + e.kind); 
		switch(e.kind) {
			case "lowpass_filter" :
				var bytes = getTmpBytes(4);
				bytes.setInt32(0, e.handle);
				EFX.deleteFilters(1, bytes);
			default :
		}
	}

	public function updateEffect(e : Effect) {
		switch (e.kind) {
			case "lowpass_filter" :
				var e = Std.instance(e, hxd.snd.effect.LowPassFilter);
				EFX.filterf(e.handle, EFX.LOWPASS_GAIN,   e.gain);
				EFX.filterf(e.handle, EFX.LOWPASS_GAINHF, e.gainHF);
			default :
		}
		
	}

	public function bindEffect(e : Effect, source : SourceHandle) {
		switch(e.kind) {
			case "lowpass_filter" : 
				AL.sourcei(source, EFX.DIRECT_FILTER, e.handle); 
			default :
		}
	}

	public function applyEffect(e : Effect, source : SourceHandle) {
		switch (e.kind) {
			case "lowpass_filter" :
				// should be only if the effect params changed
				AL.sourcei(source, EFX.DIRECT_FILTER, e.handle); 
			default :
		}
	}

	public function unbindEffect(e : Effect, source : SourceHandle) {
		switch (e.kind) {
			case "lowpass_filter" : 
				AL.sourcei(source, EFX.DIRECT_FILTER, EFX.FILTER_NULL);
			default :
		}
	}
}

/*override function onAlloc() {
		super.onAlloc();
		EFX.filteri(instance, EFX.FILTER_TYPE, EFX.FILTER_LOWPASS);
	}

	override function apply(source : Driver.Source) {
		if (changed) {
			EFX.filterf(instance, EFX.LOWPASS_GAIN,   gain);
			EFX.filterf(instance, EFX.LOWPASS_GAINHF, gainHF);
			changed = false;
		}
		super.apply(source);
	}*/

/*
// apply pitch

override function apply(s : Driver.Source) {
	AL.sourcef(s.inst, AL.PITCH, value);
}

override function unapply(s : Driver.Source) {
	AL.sourcef(s.inst, AL.PITCH,  1.);
}

*/

/*
// apply spatialization

override function apply(s : Driver.Source) {
	AL.sourcei(s.inst,  AL.SOURCE_RELATIVE, AL.FALSE);

	AL.source3f(s.inst, AL.POSITION,  -position.x,  position.y,  position.z);
	AL.source3f(s.inst, AL.VELOCITY,  -velocity.x,  velocity.y,  velocity.z);
	AL.source3f(s.inst, AL.DIRECTION, -direction.x, direction.y, direction.z);

	AL.sourcef(s.inst, AL.REFERENCE_DISTANCE, referenceDistance);
	AL.sourcef(s.inst, AL.ROLLOFF_FACTOR, rollOffFactor);

	AL.sourcef(s.inst, AL.MAX_DISTANCE, maxDistance == null ? 3.40282347e38 : (maxDistance:Float) );
}

override function unapply(s : Driver.Source) {
	AL.sourcei (s.inst, AL.SOURCE_RELATIVE, AL.TRUE);
	AL.source3f(s.inst, AL.POSITION,  0, 0, 0);
	AL.source3f(s.inst, AL.VELOCITY,  0, 0, 0);
	AL.source3f(s.inst, AL.DIRECTION, 0, 0, 0);
}*/


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