package hxd.snd;

import hxd.snd.Driver;

@:access(hxd.snd.Manager)
class Source {
	static var ID = 0;

	public var id (default, null) : Int;
	public var handle  : SourceHandle;
	public var channel : Channel;
	public var buffers : Array<Buffer>;
	
	public var volume   = 1.;
	public var playing  = false;
	public var position = 0;

	public function new(driver : Driver) {
		id        = ID++;
		handle    = driver.createSource();
		buffers   = [];
	}

	public function dispose() {
		Manager.get().driver.destroySource(handle);
	}
}

@:access(hxd.snd.Manager)
class Buffer {
	public var handle   : BufferHandle;
	public var isEnd    : Bool;
	public var isStream : Bool;
	public var refs     : Int;

	public var start    : Int;
	public var samples  : Int;
	public var sound    : hxd.res.Sound;

	public function new(driver : Driver) {
		handle = driver.createBuffer();
		refs = 0;
	}

	public function dispose() {
		Manager.get().driver.destroyBuffer(handle);
	}
}

class Manager {
	// Automatically set the channel to streaming mode if its duration exceed this value.
	public static var STREAM_DURATION = 5.;
	public static var STREAM_BUFFER_SAMPLE_COUNT = 44100;
	static inline var MAX_SOURCES     = 16;
	
	static var instance : Manager;

	public var masterVolume	: Float;
	public var masterSoundGroup   (default, null) : SoundGroup;
	public var masterChannelGroup (default, null) : ChannelGroup;
	public var listener : Listener;

	var cachedBytes   : haxe.io.Bytes;
	var resampleBytes : haxe.io.Bytes;

	var driver   : Driver;
	var channels : Channel;
	var sources  : Array<Source>;

	var soundBufferMap    : Map<String, Buffer>;
	var freeStreamBuffers : Array<Buffer>; 

	private function new() {
		#if usesys
		driver = new haxe.AudioTypes.DriverImpl();
		#else
		driver = new hxd.snd.openal.AudioTypes.DriverImpl();
		#end

		masterVolume       = 1.0;
		masterSoundGroup   = new SoundGroup  ("master");
		masterChannelGroup = new ChannelGroup("master");
		listener  = new Listener();
		soundBufferMap = new Map();
		freeStreamBuffers = [];

		// alloc sources
		sources = [];
		for (i in 0...MAX_SOURCES) sources.push(new Source(driver));

		cachedBytes = haxe.io.Bytes.alloc(4 * 3 * 2);
	}

	function getTmpBytes(size) {
		if (cachedBytes.length < size)
			cachedBytes = haxe.io.Bytes.alloc(size);
		return cachedBytes;
	}

	function getResampleBytes(size) {
		if (resampleBytes.length < size)
			resampleBytes = haxe.io.Bytes.alloc(size);
		return resampleBytes;
	}

	public static function get() : Manager {
		if( instance == null ) {
			instance = new Manager();
			haxe.MainLoop.add(instance.update);
		}
		return instance;
	}

	public function stopAll() {
		while( channels != null )
			channels.stop();
	}

	public function dispose() {
		stopAll();

		for (s in sources) driver.destroySource(s.handle);
		for (b in soundBufferMap) driver.destroyBuffer(b.handle);
		
		sources = [];
		soundBufferMap = null;

		driver.dispose();
	}

	public function play(sound : hxd.res.Sound, ?channelGroup : ChannelGroup, ?soundGroup : SoundGroup) {
		if (soundGroup   == null) soundGroup   = masterSoundGroup;
		if (channelGroup == null) channelGroup = masterChannelGroup;

		var c = new Channel();
		c.sound        = sound;
		c.manager      = this;
		c.soundGroup   = soundGroup;
		c.channelGroup = channelGroup;
		c.next         = channels;
		
		channels = c;
		return c;
	}

	public function update() {
		var now = haxe.Timer.stamp();

		// --------------------------------------------------------------------
		// (de)queue buffers, sync positions & release ended channels
		// --------------------------------------------------------------------

		for (s in sources) {
			var c = s.channel;
			if (c == null) continue;

			// process consumed buffers
			var lastBuffer = null;
			var count = driver.getProcessedBuffers(s.handle);
			for (i in 0...count) {
				// unqueue & unref processed buffers
				var b = s.buffers.shift();
				driver.unqueueBuffer(s.handle, b.handle);
				if (b.isStream) freeStreamBuffers.unshift(b);
				else --b.refs;
				c.sound = b.sound;
				lastBuffer = b;

				if (b.isEnd) {
					c.onEnd();
					s.position = 0;
				} else {
					s.position += b.samples;
				}
			}

			// enqueue buffers
			if (s.buffers.length < 2) {
				var b = s.buffers.length > 0
					? s.buffers[s.buffers.length - 1]
					: lastBuffer;

				if (!b.isEnd) {
					// next stream buffer
					queueBuffer(s, b.sound, b.start + b.samples);
				} else if (c.queue.length > 0) {
					// queue next sound buffer
					queueBuffer(s, c.queue.shift(), 0);
				} else if (c.loop) {
					// requeue last played sound
					queueBuffer(s, b.sound, 0);
				}
			}

			// source ended ?
			if (s.buffers.length == 0) {
				releaseChannel(c);
				continue;
			}

			// ensure that the source is still playing
			// game stalls may process all buffers before queueing
			switch(driver.getSourceState(s.handle)) {
				case Stopped : driver.playSource(s.handle);
				case Unhandled : throw "unhandled source state";
				default :
			}
		}

		// --------------------------------------------------------------------
		// calc audible gain & virtualize inaudible channels
		// --------------------------------------------------------------------

		var c = channels;
		while (c != null) {
			c.calcAudibleGain(now);
			c.isVirtual = c.pause || c.mute || c.channelGroup.mute || c.audibleGain < 1e-5;
			c = c.next;
		}

		// --------------------------------------------------------------------
		// sort channels by priority
		// --------------------------------------------------------------------

		channels = haxe.ds.ListSort.sortSingleLinked(channels, sortChannel);

		// --------------------------------------------------------------------
		// virtualize sounds that puts the put the audible count over the maximum number of sources
		// --------------------------------------------------------------------

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

		// --------------------------------------------------------------------
		// free sources that points to virtualized channels
		// --------------------------------------------------------------------

		for (s in sources) {
			if (s.channel == null || !s.channel.isVirtual) continue;
			releaseSource(s);
		}

		// --------------------------------------------------------------------
		// bind non-virtual channels to sources
		// --------------------------------------------------------------------

		var c = channels;
		while (c != null) {
			if (c.source != null || c.isVirtual) {
				c = c.next;
				continue;
			}

			// look for a free source
			var s = null;
			for (s2 in sources) if( s2.channel == null ) {
				s = s2;
				break;
			} 
			
			if (s == null) throw "could not get a source";
			s.channel = c;
			c.source = s;

			s.position = 0;
			var start = 0; // todo calc sample start
			queueBuffer(s, c.sound, start);

			c = c.next;
		}

		// --------------------------------------------------------------------
		// update source parameters & register used effects
		// --------------------------------------------------------------------
		
		var usedEffects : Effect = null;

		for (s in sources) {
			var c = s.channel;
			if (c == null) continue;
			
			var v = c.currentVolume;
			if (s.volume != v) {
				s.volume = v;
				driver.setSourceVolume(s.handle, v);
			}

			if (!s.playing) {
				driver.playSource(s.handle);
				s.playing = true;
			}

			usedEffects = syncEffects(c, s, usedEffects);
		}

		// --------------------------------------------------------------------
		// update used effects
		// --------------------------------------------------------------------

		var e = usedEffects;
		while (e != null) {
			driver.updateEffect(e);
			e = e.next;
		}
		
		// --------------------------------------------------------------------
		// update virtual channels
		// --------------------------------------------------------------------

		var c = channels;
		while (c != null) {
			if (c.pause || !c.isVirtual) {
				c = c.next;
				continue;
			}

			c.position += now - c.lastStamp;
			c.lastStamp = now;

			var next = c.next; // save next, since we might release this channel
			while (c.position >= c.duration) {
				c.position -= c.duration;

				if (c.loop && c.queue.length == 1) {
					c.onEnd();
					continue;
				} 

				if (c.queue.shift() == null) {
					releaseChannel(c);
					c.onEnd();
					break;
				}
			}
			c = next;
		}

		// --------------------------------------------------------------------
		// update global driver parameters
		// --------------------------------------------------------------------

		listener.direction.normalize();
		listener.up.normalize();

		driver.setMasterVolume(masterVolume);
		driver.setListenerParams(listener.position, listener.direction, listener.up, listener.velocity);

		driver.update();
	}

	// ------------------------------------------------------------------------
	// internals
	// ------------------------------------------------------------------------

	function queueBuffer(s : Source, snd : hxd.res.Sound, start : Int) {
		var data   = snd.getData();
		var sgroup = s.channel.soundGroup;

		if (data.duration <= STREAM_DURATION) {
			// queue sound buffer
			var b = getSoundBuffer(snd, sgroup);
			driver.queueBuffer(s.handle, b.handle, start, true);
			s.buffers.push(b);
		} else {
			// queue stream buffer
			var b = getStreamBuffer(snd, sgroup, start);
			driver.queueBuffer(s.handle, b.handle, 0, b.isEnd);
			s.buffers.push(b);
		}

		s.channel.positionChanged = false;
	}

	static function regEffect(list : Effect, e : Effect) : Effect {
		while (list != null) {
			if (list == e) return list;
			list = list.next;
		}
		e.next = list;
		return e;
	}

	function syncEffects(c : Channel, s : Source, usedEffects : Effect) {
		// unbind removed effects
		for (e in c.bindedEffects) {
			if (c.effects.indexOf(e) >= 0 || c.channelGroup.effects.indexOf(e) >= 0)
				continue;
			driver.unbindEffect(e, s.handle);
			c.bindedEffects.remove(e);
		}

		// bind effects added in the channel group
		for (e in c.channelGroup.effects) {
			if (c.bindedEffects.indexOf(e) < 0) {
				driver.bindEffect(e, s.handle);
				c.bindedEffects.push(e);
			}
			driver.applyEffect(e, s.handle);
		}

		// bind effects added in the channel
		for (e in c.effects) {
			if (c.bindedEffects.indexOf(e) < 0) {
				driver.bindEffect(e, s.handle);
				c.bindedEffects.push(e);
			}
			driver.applyEffect(e, s.handle);
		}

		// register used effects
		for (e in c.effects) usedEffects = regEffect(usedEffects, e);
		for (e in c.channelGroup.effects) usedEffects = regEffect(usedEffects, e);

		return usedEffects;
	}

	function releaseSource(s : Source) {
		trace("release source");

		if (s.channel != null) {
			for (e in s.channel.bindedEffects) driver.unbindEffect(e, s.handle);
			s.channel.bindedEffects = [];
			s.channel.source = null;
			s.channel = null;
		}

		for (b in s.buffers)
			driver.unqueueBuffer(s.handle, b.handle);

		if (s.playing) {
			s.playing = false;
			driver.stopSource(s.handle);
		}

		s.buffers = [];
	}

	var targetRate     : Int;
	var targetFormat   : Data.SampleFormat;
	var targetChannels : Int;

	function checkTargetFormat(dat : hxd.snd.Data, forceMono = false) {
		targetRate = dat.samplingRate;
		#if !hl
		// perform resampling to nativechannel frequency
		targetRate = AL.NATIVE_FREQ;
		#end
		targetChannels = forceMono || dat.channels == 1 ? 1 : 2;
		targetFormat   = switch (dat.sampleFormat) {
		case UI8 : UI8;
		case I16 : I16;
		case F32 :
			#if hl
			I16;
			#else
			F32;
			#end
		}
		return targetChannels == dat.channels && targetFormat == dat.sampleFormat && targetRate == dat.samplingRate;
	}

	function getSoundBuffer(snd : hxd.res.Sound, grp : SoundGroup) : Buffer {
		var data = snd.getData();
		var mono = grp.mono;
		var key  = snd.name;

		if (mono && data.channels != 1) key += "mono";

		var b = soundBufferMap.get(key);
		if (b == null) {
			b = new Buffer(driver);
			b.isStream = false;
			b.isEnd = true;
			b.sound = snd;
			soundBufferMap.set(key, b);
			data.load(function() fillSoundBuffer(b, data, mono));
		}

		++b.refs;
		return b;
	}

	function getStreamBuffer(snd : hxd.res.Sound, grp : SoundGroup, start : Int) : Buffer {
		var data = snd.getData();

		var b = freeStreamBuffers.shift();
		if (b == null) {
			b = new Buffer(driver);
			b.isStream = true;
		}

		var samples = STREAM_BUFFER_SAMPLE_COUNT;
		if (start + samples > data.samples) {
			samples = data.samples - start;
			b.isEnd = true;
		} else {
			b.isEnd = false;
		}

		b.sound   = snd;
		b.samples = samples;
		b.start   = start;

		var size  = samples * data.getBytesPerSample();
		var bytes = getTmpBytes(size);
		data.decode(bytes, 0, start, samples);

		if (!checkTargetFormat(data, grp.mono)) {
			size = samples * targetChannels * Data.formatBytes(targetFormat);
			var resampleBytes = getResampleBytes(size);
			data.resampleBuffer(resampleBytes, 0, bytes, 0, targetRate, targetFormat, targetChannels, samples);
			bytes = resampleBytes;
		}

		driver.setBufferData(b.handle, bytes, size, targetFormat, targetChannels, targetRate);
		return b;
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
		trace("release channel");
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

	function fillSoundBuffer(buf : Buffer, dat : hxd.snd.Data, forceMono = false) {
		if (!checkTargetFormat(dat, forceMono))
			dat = dat.resample(targetRate, targetFormat, targetChannels);

		var length = dat.samples * dat.getBytesPerSample();
		var bytes  = getTmpBytes(length);
		dat.decode(bytes, 0, 0, dat.samples);
		driver.setBufferData(buf.handle, bytes, length, targetFormat, targetChannels, dat.samplingRate);
	}
}