package hxd.snd;

import hxd.snd.Driver;

@:access(hxd.snd.Manager)
class Source {
	public var handle  : SourceHandle;
	public var channel : Channel;
	public var buffers : Array<Buffer>;

	public var loop     = false;
	public var volume   = 1.;
	public var playing  = false;
	public var hasQueue = false;

	public var streamData         : hxd.snd.Data;
	public var streamSample       : Int;
	public var streamPosition     : Float;
	public var streamPositionNext : Float;

	public function new(driver : Driver) {
		handle  = driver.createSource();
		buffers = [];
	}
}

@:access(hxd.snd.Manager)
class Buffer {
	public var handle    : BufferHandle;
	public var sound     : hxd.res.Sound;
	public var playCount : Int;
	public var lastStop  : Float;

	public function new(driver : Driver) {
		handle = driver.createBuffer();
	}

	public function unref() {
		if( sound == null ) {
			Manager.get().driver.destroyBuffer(handle);
		} else {
			playCount--;
			if( playCount == 0 ) lastStop = haxe.Timer.stamp();
		}
	}
}

class Manager {

	/**
		When a channel is streaming, how much data should be bufferize.
	**/
	public static var STREAM_BUFSIZE = 1 << 19;

	/**
		Automatically set the channel to streaming mode if its duration exceed this value.
	**/
	public static var STREAM_DURATION = 5.;
	static inline var MAX_SOURCES     = 16;

	static var instance : Manager;

	public var masterVolume	: Float;
	public var masterSoundGroup   (default, null) : SoundGroup;
	public var masterChannelGroup (default, null) : ChannelGroup;
	public var listener : Listener;

	var cachedBytes   : haxe.io.Bytes;
	var resampleBytes : haxe.io.Bytes;

	var driver      : Driver;
	var channels    : Channel;
	var buffers     : Array<Buffer>;
	var sources     : Array<Source>;
	var bufferMap   : Map<hxd.res.Sound, Buffer>;

	var preUpdateCallbacks  : Array<Void->Void>;
	var postUpdateCallbacks : Array<Void->Void>;

	// ------------------------------------------------------------------------

	private function new() {
		#if usesys
		driver = new haxe.AudioTypes.DriverImpl();
		#else
		driver = new hxd.snd.openal.AudioTypes.DriverImpl();
		#end

		masterVolume       = 1.0;
		masterSoundGroup   = new SoundGroup  ("master");
		masterChannelGroup = new ChannelGroup("master");
		listener = new Listener();

		buffers = [];
		bufferMap = new Map();

		preUpdateCallbacks  = [];
		postUpdateCallbacks = [];

		{	// alloc sources
			sources = [];
			for (i in 0...MAX_SOURCES) sources.push(new Source(driver));
		}

		cachedBytes = haxe.io.Bytes.alloc(4 * 3 * 2);
	}

	public function addPreUpdateCallback(f : Void->Void) {
		preUpdateCallbacks.push(f);
	}

	public function addPostUpdateCallback(f : Void->Void) {
		postUpdateCallbacks.push(f);
	}

	function getTmp(size) {
		if( cachedBytes.length < size )
			cachedBytes = haxe.io.Bytes.alloc(size);
		return cachedBytes;
	}

	static function soundUpdate() {
		if( instance != null ) {
			for (f in instance.preUpdateCallbacks) f();
			instance.update();
			for (f in instance.postUpdateCallbacks) f();
		}
	}

	public static function get() : Manager {
		if( instance == null ) {
			instance = new Manager();
			haxe.MainLoop.add(soundUpdate);
		}
		return instance;
	}

	public function stopAll() {
		while( channels != null )
			channels.stop();
	}

	public function cleanCache() {
		for( b in buffers.copy() )
			if( b.playCount == 0 )
				releaseBuffer(b);
	}

	public function dispose() {
		stopAll();

		for (s in sources) driver.destroySource(s.handle);
		for (b in buffers) driver.destroyBuffer(b.handle);
		
		sources = [];
		buffers = [];

		driver.dispose();
	}

	public function play(sound : hxd.res.Sound, ?channelGroup : ChannelGroup, ?soundGroup : SoundGroup) {
		if (soundGroup   == null) soundGroup   = masterSoundGroup;
		if (channelGroup == null) channelGroup = masterChannelGroup;
		var c = new Channel();
		c.manager = this;
		c.sound = sound;
		c.duration = c.sound.getData().duration;
		c.soundGroup   = soundGroup;
		c.channelGroup = channelGroup;
		c.next = channels;
		c.streaming = c.duration > STREAM_DURATION;
		channels = c;
		return c;
	}

	public function update() {
		driver.update();

		// update playing channels from sources & release stopped channels
		var now = haxe.Timer.stamp();
		for( s in sources ) {
			var c = s.channel;
			if( c == null ) continue;
			var state = driver.getSourceState(s.handle);
			switch (state) {
			case Stopped :
				if (c.streaming && s.streamPosition != s.streamPositionNext) {
					// force full resync
					releaseSource(s);
					continue;
				}
				releaseChannel(c);
				c.onEnd();
			case Playing :
				if( c.streaming ) {
					if( c.positionChanged ) {
						// force full resync
						releaseSource(s);
						continue;
					}
					var count = driver.getProcessedBuffers(s.handle);
					if( count > 0 ) {
						// swap buffers
						var b0 = s.buffers[0];
						var b1 = s.buffers[1];
						driver.unqueueBuffer(s.handle, b0.handle);
						s.streamPosition = s.streamPositionNext;
						updateStreaming(s, b0, c.soundGroup.mono);
						driver.queueBuffer(s.handle, b0.handle);
						s.buffers[0] = b1;
						s.buffers[1] = b0;
					}

					var position = driver.getSourcePosition(s.handle);
					c.position = position + s.streamPosition;
					c.lastStamp = now;
					if( c.position > c.duration ) {
						if( c.queue.length > 0 ) {
							s.streamPosition -= c.duration;
							queueNext(c);
							c.onEnd();
						} else if( c.loop ) {
							c.position -= c.duration;
							s.streamPosition -= c.duration;
							c.onEnd();
						}
					}
					c.positionChanged = false;
				} else if( !c.positionChanged ) {
					var position = driver.getSourcePosition(s.handle);
					var prev = c.position;
					c.position = position;
					c.lastStamp = now;
					c.positionChanged = false;
					if( c.queue.length > 0 ) {
						var count = driver.getProcessedBuffers(s.handle);
						while( count > 0 ) {
							driver.unqueueBuffer(s.handle, s.buffers[0].handle);
							queueNext(c);
							count--;
							c.onEnd();
						}
					} else if( position < prev )
						c.onEnd();
				}
			default:
			}
		}

		// calc audible gain & virtualize inaudible channels
		var c = channels;
		while (c != null) {
			c.calcAudibleGain(now);
			c.isVirtual = c.pause || c.mute || c.channelGroup.mute || c.audibleGain < 1e-5;
			c = c.next;
		}

		// sort channels by priority
		channels = haxe.ds.ListSort.sortSingleLinked(channels, sortChannel);

		{	// virtualize sounds that puts the put the audible count over the maximum number of sources
			var sgroupRefs = new Map<SoundGroup, Int>();
			var audibleCount = 0;
			var c = channels;
			while (c != null && !c.isVirtual) {
				if (++audibleCount > sources.length) c.isVirtual = true;
				else if (c.soundGroup.maxAudible >= 0) {
					var sgRefs = sgroupRefs.get(c.soundGroup);
					if (sgRefs == null) sgRefs = 0;
					if (++sgRefs > c.soundGroup.maxAudible) {
						c.isVirtual = true;
						--audibleCount;
					}
					sgroupRefs.set(c.soundGroup, sgRefs);
				}
				c = c.next;
			}
		}

		// free sources that points to virtualized channels
		for ( s in sources ) {
			if ( s.channel == null || !s.channel.isVirtual) continue;
			releaseSource(s);
		}

		// update listener parameters
		listener.direction.normalize();
		listener.up.normalize();

		driver.setMasterVolume(masterVolume);
		driver.setListenerParams(listener.position, listener.direction, listener.up, listener.velocity);

		// bind sources to non virtual channels
		var c = channels;
		while (c != null) {
			if( c.source != null || c.isVirtual ) {
				c = c.next;
				continue;
			}

			// look for a free source
			var s = null;
			for( s2 in sources )
				if( s2.channel == null ) {
					s = s2;
					break;
				}
			if( s == null ) throw "assert";
			s.channel = c;
			c.source = s;

			// bind buf and force full sync
			syncBuffers(s, c);
			c.positionChanged = true;
			c = c.next;
		}

		{ // update effect parameters
			var usedEffects = null;
			for (s in sources) {
				var c = s.channel;
				if (c == null) continue;
				for (e in c.effects)              usedEffects = regEffect(usedEffects, e);
				for (e in c.channelGroup.effects) usedEffects = regEffect(usedEffects, e);
			}
			var e = usedEffects;
			while (e != null) {
				driver.updateEffect(e);
				e = e.next;
			}
		}

		// update source parameters
		for (s in sources) {
			var c = s.channel;
			if( c == null) continue;
			syncSource(s);
		}
		
		var c = channels;
		while (c != null) {
			var next = c.next;
			// update virtual channels
			if (!c.pause && c.isVirtual) {
				c.position += now - c.lastStamp;
				c.lastStamp = now;
				if( c.position >= c.duration && !queueNext(c) && !c.loop ) {
					releaseChannel(c);
					c.onEnd();
				}
			}
			c = next;
		}

		driver.update();
	}

	function syncSource( s : Source ) {
		var c = s.channel;
		if( c == null ) return;
		if( c.positionChanged ) {
			if( !c.streaming ) {
				driver.setSourcePosition(s.handle, c.position);
				c.position = driver.getSourcePosition(s.handle); // prevent rounding
			}
			c.positionChanged = false;
		}
		var loopFlag = c.loop && c.queue.length == 0 && !c.streaming;
		if( s.loop != loopFlag ) {
			s.loop = loopFlag;
			driver.setSourceLooping(s.handle, loopFlag);
		}
		var v = c.currentVolume;
		if( s.volume != v ) {
			s.volume = v;
			driver.setSourceVolume(s.handle, v);
		}

		syncEffects(c, s);

		if( !s.playing ) {
			s.playing = true;
			driver.playSource(s.handle);
		}
	}

	static function regEffect(list : Effect, e : Effect) : Effect {
		while (list != null) {
			if (list == e) return list;
			list = list.next;
		}
		e.next = list;
		return e;
	}

	function syncEffects(c : Channel, s : Source) {
		for (e in c.bindedEffects) {
			if (c.effects.indexOf(e) >= 0 || c.channelGroup.effects.indexOf(e) >= 0)
				continue;
			driver.unbindEffect(e, s.handle);
			c.bindedEffects.remove(e);
		}

		for (e in c.channelGroup.effects) {
			if (c.bindedEffects.indexOf(e) < 0) {
				driver.bindEffect(e, s.handle);
				c.bindedEffects.push(e);
			}
			driver.applyEffect(e, s.handle);
		}

		for (e in c.effects) {
			if (c.bindedEffects.indexOf(e) < 0) {
				driver.bindEffect(e, s.handle);
				c.bindedEffects.push(e);
			}
			driver.applyEffect(e, s.handle);
		}	
	}

	function queueNext( c : Channel ) {
		var snd = c.queue.shift();
		if( snd == null )
			return false;
		c.sound = snd;
		c.position -= c.duration;
		c.duration = snd.getData().duration;
		c.positionChanged = false;
		return true;
	}

	// ------------------------------------------------------------------------
	// internals
	// ------------------------------------------------------------------------

	function releaseSource( s : Source ) {
		if (s.channel != null) {
			for (e in s.channel.bindedEffects) driver.unbindEffect(e, s.handle);
			s.channel.bindedEffects = [];
			s.channel.source = null;
			s.channel = null;
		}
		if (s.playing) {
			s.playing = false;
			driver.stopSource(s.handle);
		}
		syncBuffers(s, null);
	}

	function syncBuffers( s : Source, c : Channel ) {
		if( c == null ) {
			if( s.buffers.length == 0 )
				return;
			if( !s.hasQueue )
				driver.removeSourceBuffer(s.handle);
			else for( b in s.buffers ) 
				driver.unqueueBuffer(s.handle, b.handle);

			for( b in s.buffers )
				b.unref();
			s.buffers = [];
			s.streamData = null;
			s.hasQueue = false;

		} else if( c.streaming ) {

			if( !s.hasQueue ) {
				if( s.buffers.length != 0 ) throw "assert";
				s.hasQueue     = true;
				s.buffers      = [new Buffer(driver), new Buffer(driver)];
				s.streamData   = c.sound.getData();
				s.streamSample = Std.int(c.position * s.streamData.samplingRate);
				// fill first two buffers
				updateStreaming(s, s.buffers[0], c.soundGroup.mono);
				s.streamPosition = s.streamPositionNext;
				updateStreaming(s, s.buffers[1], c.soundGroup.mono);
				driver.queueBuffer(s.handle, s.buffers[0].handle);
				driver.queueBuffer(s.handle, s.buffers[1].handle);

				/*var error = AL.getError();
				if( error != 0 )
					throw "Failed to queue streaming buffers 0x"+StringTools.hex(error);*/
			}

		} else if( s.hasQueue || c.queue.length > 0 ) {

			if( !s.hasQueue && s.buffers.length > 0 )
				throw "Can't queue on a channel that is currently playing an unstreamed data";

			var buffers = [getBuffer(c.sound, c.soundGroup)];
			for( snd in c.queue )
				buffers.push(getBuffer(snd, c.soundGroup));

			// only append new ones
			for( i in 0...s.buffers.length ) if( buffers.shift() != s.buffers[i] )
				throw "assert";

			for (b in buffers) {
				b.playCount++;
				driver.queueBuffer(s.handle, b.handle);
				s.buffers.push(b);
			}

			//if( AL.getError() != 0 )
			//	throw "Failed to queue buffers : format differs";

		} else {
			var buffer = getBuffer(c.sound, c.soundGroup);
			//AL.sourcei(s.inst, AL.BUFFER, buffer.inst.toInt());
			driver.setSourceBuffer(s.handle, buffer.handle);
			if( s.buffers[0] != null )
				s.buffers[0].unref();
			s.buffers[0] = buffer;
			buffer.playCount++;
		}
	}

	var targetRate : Int;
	var targetFormat : Data.SampleFormat;
	var targetChannels : Int;

	function checkTargetFormat( dat : hxd.snd.Data, forceMono = false ) {
		targetRate = dat.samplingRate;
		#if !hl
		// perform resampling to nativechannel frequency
		targetRate = AL.NATIVE_FREQ;
		#end
		targetChannels = forceMono || dat.channels == 1 ? 1 : 2;
		targetFormat   = switch (dat.sampleFormat) {
		case UI8: UI8;
		case I16: I16;
		case F32:
			#if hl
			I16;
			#else
			F32;
			#end
		}
		return targetChannels == dat.channels && targetFormat == dat.sampleFormat && targetRate == dat.samplingRate;
	}

	function updateStreaming( s : Source, buf : Buffer, forceMono : Bool ) {
		// decode
		var tmpBytes = getTmp(STREAM_BUFSIZE >> 1);
		var bpp = s.streamData.getBytesPerSample();
		var reqSamples = Std.int((STREAM_BUFSIZE >> 1) / bpp);
		var samples = reqSamples;
		var outPos = 0;
		var qPos = 0;

		while( samples > 0 ) {
			var avail = s.streamData.samples - s.streamSample;
			if( avail <= 0 ) {
				var next = s.channel.queue[qPos++];
				if( next != null ) {
					s.streamSample -= s.streamData.samples;
					s.streamData = next.getData();
				} else if( !s.channel.loop || s.streamData.samples == 0 )
					break;
				else
					s.streamSample -= s.streamData.samples;
			} else {
				var count = samples < avail ? samples : avail;
				if( outPos == 0 )
					s.streamPositionNext = s.streamSample / s.streamData.samplingRate;
				s.streamData.decode(tmpBytes, outPos, s.streamSample, count);
				s.streamSample += count;
				outPos += count * bpp;
				samples -= count;
			}
		}

		if( !checkTargetFormat(s.streamData, forceMono) ) {
			reqSamples -= samples;
			var bytes = resampleBytes;
			var reqBytes = targetChannels * reqSamples * Data.formatBytes(targetFormat);
			if( bytes == null || bytes.length < reqBytes ) {
				bytes = haxe.io.Bytes.alloc(reqBytes);
				resampleBytes = bytes;
			}
			s.streamData.resampleBuffer(resampleBytes, 0, tmpBytes, 0, targetRate, targetFormat, targetChannels, targetRate);
			driver.setBufferData(buf.handle, resampleBytes, reqBytes, targetFormat, targetChannels, reqSamples);
		} else {
			driver.setBufferData(buf.handle, tmpBytes, outPos, targetFormat, targetChannels, s.streamData.samplingRate);
		}
	}

	function getBuffer( snd : hxd.res.Sound, grp : SoundGroup ) : Buffer {
		var b = bufferMap.get(snd);
		if( b != null )
			return b;
		if( buffers.length >= 256 ) {
			// cleanup unused buffers
			var now = haxe.Timer.stamp();
			for( b in buffers.copy() )
				if( b.playCount == 0 && b.lastStop < now - 60 )
					releaseBuffer(b);
		}
		var b = new Buffer(driver);
		b.sound = snd;
		buffers.push(b);
		bufferMap.set(snd, b);
		var data = snd.getData();
		var mono = grp.mono;
		data.load(function() fillBuffer(b, data, mono));
		return b;
	}

	function releaseBuffer( b : Buffer ) {
		buffers.remove(b);
		bufferMap.remove(b.sound);
		@:privateAccess b.sound.data = null; // free cached decoded data
		driver.destroyBuffer(b.handle);
	}

	function sortChannel(a : Channel, b : Channel) {
		if (a.isVirtual != b.isVirtual)
			return a.isVirtual ? 1 : -1;

		if (a.channelGroup.priority != b.channelGroup.priority)
			return a.channelGroup.priority < b.channelGroup.priority ? 1 : -1;

		if (a.priority != b.priority)
			return a.priority < b.priority ? 1 : -1;

		if (a.audibleGain != b.audibleGain)
			return a.audibleGain < b.audibleGain ? 1 : -1;

		return a.id < b.id ? 1 : -1;
	}

	function releaseChannel(c : Channel) {
		if (channels == c) {
			channels = c.next;
		} else {
			var prev = channels;
			while (prev.next != c)
				prev = prev.next;
			prev.next = c.next;
		}

		for (e in c.effects) c.removeEffect(e);
		if (c.source != null) releaseSource(c.source);
		c.next = null;
		c.manager = null;
		c.effects = null;
		c.bindedEffects = null;
	}

	function fillBuffer(buf : Buffer, dat : hxd.snd.Data, forceMono = false) {
		if( !checkTargetFormat(dat, forceMono) )
			dat = dat.resample(targetRate, targetFormat, targetChannels);
		var dataBytes = haxe.io.Bytes.alloc(dat.samples * dat.getBytesPerSample());
		dat.decode(dataBytes, 0, 0, dat.samples);
		driver.setBufferData(buf.handle, dataBytes, dataBytes.length, targetFormat, targetChannels, dat.samplingRate);
	}
}