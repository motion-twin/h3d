package hxd.net;
import hxd.net.NetworkHost;

typedef SafeChunk = {
	var idx : Int;
	var type : Int;
	var bytes : haxe.io.Bytes;
};

typedef PacketData = {
	var id : Int;
	var tick : Int;
	var sent : Float;
	var changes : Map<Int,Int>;
	var safeChunks : Array<SafeChunk>;
};

// TODO split packets (simple fragment and/or split safe chunks)

// Packet structure
// CRC     4 [crc32]
// GLOBAL  8 [packetId:16][lastAck:16][ackSeq:32]
// SUBPKT  1 [type:8][len:Size]
// SYNC	             [tick:32]([uid:32][len:Size]props*)*
// XRPC              // TODO
// *                 [id:16] // TODO id-rotation

class UdpClient extends NetworkClient {
	
	public var ip : String;
	public var port : Int;
	
	// Sender
	var pktId : Int;
	var sentPackets : Map<Int,PacketData>;
	var rtt : Float;
	var localChanges : Map<Int,Int>;
	var sSafeBuffer : Array<SafeChunk>;
	var sSafeIndex : Int;
	
	// Receiver
	var newAck : Bool;
	var ack : Array<Int>;
	var rSafeIndex : Int;
	var rSafeBuffer : Map<Int,{type: Int, bytes: haxe.io.Bytes}>;
	var deferSync : Map<Int,Array<haxe.io.Bytes>>;
	
	public function new(host,ip:String=null,port:Int=0) {
		super(host);
		this.ip = ip;
		this.port = port;
		this.pktId = 0;
		this.newAck = false;
		this.ack = [];
		this.rtt = -1.0;
		this.sentPackets = new Map();
		this.sSafeBuffer = [];
		this.sSafeIndex = 0;
		this.rSafeBuffer = new Map();
		this.rSafeIndex = 0;
		this.deferSync = new Map();
	}
	
	function onAck( pktId : Int ){
		var pkt = sentPackets.get( pktId );
		if( pkt == null )
			return;
		var tt = haxe.Timer.stamp() - pkt.sent;
		rtt = (rtt < 0) ? tt : (rtt * 9 + tt) * 0.1;
		sentPackets.remove( pktId );
	}
	
	function doProcessMessage( mid : Int, bytes : haxe.io.Bytes, ?pos : Int, ?len: Int ) {
		if( pos == null ) pos = 0;
		if( len == null ) len = bytes.length;
		var end = len + pos;
		var ctx = host.ctx;
		ctx.setInput(bytes, pos);
		switch( mid ) {
		case UdpHost.SYNC:
			ctx.tick = ctx.getInt32();
			while( @:privateAccess ctx.inPos < end ){
				var uid = ctx.getInt();
				var o : hxd.net.NetworkSerializable = cast ctx.refs[uid];
				var b = ctx.getBytes();
				if( o == null ){
					var a = deferSync.get(uid);
					if( a == null )
						deferSync.set(uid,[b]);
					else
						a.push(b);
				}else{
					syncObject(o,ctx,b);
				}
			}
			
		case UdpHost.REG:
			var o : hxd.net.NetworkSerializable = cast ctx.getAnyRef();
			host.makeAlive();
			var a = deferSync.get(o.__uid);
			if( a != null ){
				for( b in a )
					syncObject(o,ctx,b);
				deferSync.remove(o.__uid);
			}
		case UdpHost.UNREG:
			var o : hxd.net.NetworkSerializable = cast ctx.refs[ctx.getInt()];
			o.__lastChanges = null;
			o.__host = null;
			ctx.refs.remove(o.__uid);
			
		case UdpHost.FULLSYNC:
			ctx.refs = new Map();
			@:privateAccess {
				hxd.net.Serializer.UID = 0;
				hxd.net.Serializer.SEQ = ctx.getByte();
				ctx.newObjects = [];
			};
			while( true ) {
				var o = ctx.getAnyRef();
				if( o == null ) break;
			}
			host.makeAlive();
			for( k in deferSync.keys() ){
				var o : NetworkSerializable = cast ctx.refs[k];
				if( o == null ) continue;
				var a = deferSync.get(k);
				for( b in a )
					syncObject(o,ctx,b);
				deferSync.remove(k);
			}
			
		case UdpHost.RPC:
			var o : hxd.net.NetworkSerializable = cast ctx.refs[ctx.getInt()];
			var fid = ctx.getByte();
			if( !host.isAuth ) {
				var old = o.__host;
				o.__host = null;
				o.networkRPC(ctx, fid, this);
				o.__host = old;
			} else {
				host.rpcClientValue = this;
				o.networkRPC(ctx, fid, this);
				host.rpcClientValue = null;
			}
			
		// TODO
		case UdpHost.RPC_WITH_RESULT:

			var old = resultID;
			resultID = ctx.getInt();
			var o : hxd.net.NetworkSerializable = cast ctx.refs[ctx.getInt()];
			var fid = ctx.getByte();
			if( !host.isAuth ) {
				var old = o.__host;
				o.__host = null;
				o.networkRPC(ctx, fid, this);
				o.__host = old;
			} else
				o.networkRPC(ctx, fid, this);

			host.doSend();
			host.targetClient = null;
			resultID = old;

		case UdpHost.RPC_RESULT:

			var resultID = ctx.getInt();
			var callb = host.rpcWaits.get(resultID);
			host.rpcWaits.remove(resultID);
			callb(ctx);

		case UdpHost.MSG:
			var msg = haxe.Unserializer.run(ctx.getString());
			host.onMessage(this, msg);

		case UdpHost.BMSG:
			var msg = ctx.getBytes();
			host.onMessage(this, msg);
			
		case UdpHost.HELLO, UdpHost.CONNECTED:

		case x:
			error("Unknown message code " + x);
		}
		return @:privateAccess ctx.inPos;
	}
	
	function syncObject( o : NetworkSerializable, ctx : Serializer, b : haxe.io.Bytes ){
		var oldP = @:privateAccess ctx.inPos;
		var oldBytes = @:privateAccess ctx.input;
		ctx.setInput(b,0);
		var old = o.__bits;
		var oldH = o.__host;
		o.__host = null;
		o.networkSync(ctx);
		o.__host = oldH;
		o.__bits = old;
		#if debug
		if( @:privateAccess ctx.inPos != b.length )
			throw "Error. Pos="+(@:privateAccess ctx.inPos)+" Expected="+b.length+" Data="+b.toHex();
		#end
		ctx.setInput(oldBytes,oldP);
	}
		
	function processSafeData( id : Int, type: Int, bytes : haxe.io.Bytes ){
		if( id == rSafeIndex ){
			doProcessMessage(type,bytes);
			rSafeIndex++;
		}else if( id > rSafeIndex ){
			rSafeBuffer.set( id, { type: type, bytes: bytes } );
		}
		while( rSafeBuffer.exists(rSafeIndex) ){
			var s = rSafeBuffer.get(rSafeIndex);
			rSafeBuffer.remove(rSafeIndex);
			doProcessMessage(s.type,s.bytes);
			rSafeIndex++;
		}
	}
	
	public function readData( buffer : haxe.io.Bytes, pos : Int ) {
		var input = new haxe.io.BytesInput(buffer);
		input.position = pos;
		
		var id = input.readUInt16();
		
		// Ignore duplicate
		if( ack.indexOf(id) >= 0 )
			return;
		ack.push( id );
		newAck = true;
		
		var lastAck = input.readUInt16();
		var ackSeq = input.readInt32();
		if( lastAck != 0 ){
			onAck( lastAck );
			for( i in 0...32 ){
				if( ackSeq & (1<<i) != 0 )
					onAck( lastAck - i );
			}
		}
		
		while( input.position < buffer.length ){
			var type = input.readByte();
			var size = input.readByte();
			if( size == 0xFF )
				size = input.readInt32();
				
			if( type == UdpHost.SYNC ){
				doProcessMessage(type,buffer,input.position,size);
				input.position += size;
			}else{
				var safeId = input.readUInt16(); // TODO id-rotation
				var data = haxe.io.Bytes.alloc(size);
				input.readBytes(data,0,size);
				processSafeData( safeId, type, data );
			}
		}
	}
	
	function getLocalChanges() : Map<Int,Int> {
		if( localChanges == null ){
			localChanges = new Map();
			var cc = (cast host:UdpHost).curChanges;
			for( k in cc.keys() ) localChanges.set(k,cc.get(k));
		}
		return localChanges;
	}
	
	function checkPacketLost(){
		if( rtt < 0 ) return;
		var m = haxe.Timer.stamp() - rtt * 3;
		for( p in sentPackets ){
			if( p.sent < m ){
				onPacketLost(p);
				sentPackets.remove(p.id);
			}
		}
	}
	
	function onPacketLost( pkt : PacketData ){
		var ctx = host.ctx;
		for( uid in pkt.changes.keys() ){
			var o : NetworkSerializable = cast ctx.refs[uid];
			var pbits = pkt.changes[uid];
			var nbits = 0;
			if( o == null ) continue;
			
			var i = 0;
			while( 1<<i <= pbits ){
				if( pbits & 1<<i != 0 && o.__lastChanges[i] <= pkt.tick )
					nbits |= 1<<i;
				i++;
			}
			
			if( nbits > 0 ){
				var curChanges = getLocalChanges();
				var b = curChanges.get(uid);
				curChanges.set( uid, (b==null ? 0 : b) | nbits );
				
				var obits = o.__bits;
				o.__bits = nbits;
				ctx.addInt(o.__uid);
				var old = @:privateAccess ctx.out;
				@:privateAccess ctx.out = new haxe.io.BytesBuffer();
				o.networkFlush(ctx);
				var b = @:privateAccess ctx.out.getBytes();
				@:privateAccess ctx.out = old;
				ctx.addBytes(b);
				o.__bits = obits;
			}
		}
		if( pkt.safeChunks != null ){
			for( c in pkt.safeChunks )
				sSafeBuffer.push( c );
		}
	}
	
	@:allow(hxd.net.UdpHost)
	function safeSend( type: Int, bytes : haxe.io.Bytes ){
		sSafeBuffer.push({idx: sSafeIndex++, type: type, bytes: bytes});
	}
	
	public function flush( syncTick : Bool, syncPropsBytes : haxe.io.Bytes ){
		checkPacketLost();
		if( localChanges != null ){
			var localSyncProps = host.ctx.flush();
			if( syncPropsBytes == null )
				syncPropsBytes = localSyncProps;
			else{
				var b = haxe.io.Bytes.alloc( syncPropsBytes.length + localSyncProps.length );
				b.blit(0,syncPropsBytes,0,syncPropsBytes.length);
				b.blit(syncPropsBytes.length,localSyncProps,0,localSyncProps.length);
				syncPropsBytes = b;
			}
		}
		
		if( sSafeBuffer.length == 0 && syncPropsBytes == null && !newAck )
			return;
		
		pktId++;
		if( pktId > 0xFFFF )
			pktId = 1;
		
		var h : UdpHost = cast host;
		var tick = h.tick;
		var curChanges = localChanges;
		if( curChanges == null )
			curChanges = h.curChanges;
		else
			localChanges = null;
		
		var safeChunks = null;
		if( sSafeBuffer.length > 0 ){
			safeChunks = sSafeBuffer;
			sSafeBuffer = [];
		}
		
		sentPackets.set(pktId,{
			id: pktId,
			sent: haxe.Timer.stamp(),
			tick: tick,
			changes: curChanges,
			safeChunks: safeChunks,
		});
		
		var pk = new haxe.io.BytesOutput();
		var lastAck = 0;
		var ackSeq = 0;
		if( ack.length > 0 ){
			for( v in ack ) if( v > lastAck ) lastAck = v;
			
			var r = 0;
			for( v in ack ){
				if( v < lastAck - 32 ){
					if( ackSeq == 0 )
						r++;
				}else{
					ackSeq |= 1<<(lastAck-v);
				}
			}
			if( r > 0 )
				ack.splice(0,r);
			newAck = false;
		}
		pk.writeUInt16(pktId);
		pk.writeUInt16(lastAck);
		pk.writeInt32(ackSeq);
		
		inline function writeSize( size : Int ){
			if( size >= 0xFF ){
				pk.writeByte(0xFF);
				pk.writeInt32(size);
			}else
				pk.writeByte(size);
		}
		
		if( safeChunks != null ){
			for( c in safeChunks ){
				pk.writeByte(c.type);
				writeSize(c.bytes.length);
				pk.writeUInt16(c.idx);
				pk.writeBytes(c.bytes, 0, c.bytes.length);
			}
		}
		if( syncTick || syncPropsBytes != null ){
			pk.writeByte( UdpHost.SYNC );
			writeSize( syncPropsBytes==null ? 4 : syncPropsBytes.length+4 );
			pk.writeInt32((cast host:UdpHost).tick);
			if( syncPropsBytes != null ) 
				pk.writeBytes(syncPropsBytes,0,syncPropsBytes.length);
		}
		
		h.sendData(this,pk.getBytes());
	}

	public function toString(){
		return "UdpClient("+ip+":"+port+")";
	}

}

class UdpHost extends NetworkHost {

	static inline var SYNC 		= 1;
	static inline var REG 		= 2;
	static inline var UNREG 	= 3;
	static inline var FULLSYNC 	= 4;
	static inline var RPC 		= 5;
	static inline var RPC_WITH_RESULT = 6;
	static inline var RPC_RESULT = 7;
	static inline var MSG		 = 8;
	static inline var BMSG		 = 9;
	
	static inline var CONNECTED  = 0xFE;
	static inline var HELLO      = 0xFF;
	// TODO UNRELIABLE_RPC
	
	public var tick : Int;

	var connected = false;
	var onNewClient : UdpClient -> Void;
	var onConnect : Bool -> Void;
	var mClients : Map<String,UdpClient>;
	#if (flash && air3)
	var socket : flash.net.DatagramSocket;
	#end
	
	@:allow(hxd.net.UdpClient)
	var curChanges : Map<Int,Int>;
	
	#if (debug || networkConditioner)
	public var packetLossRatio = 0.0;
	public var packetDelayMin = 0.0;
	public var packetDelayMax = 0.0;
	#end

	public function new() {
		super();
		isAuth = false;
		mClients = new Map();
		curChanges = new Map();
		tick = 0;
	}

	public function close() {
		#if (flash && air3)
		if( socket != null ) {
			socket.close();
			socket = null;
		}
		#end
		connected = false;
		isAuth = false;
		self = null;
	}
	
	// TODO: Add timeout on connection and call onConnect(false)
	public function connect( host : String, port : Int, ?onConnect : Bool -> Void ) {
		#if (flash && air3)
		close();
		socket = new flash.net.DatagramSocket();
		var c = new UdpClient(this,host,port);
		self = c;
		socket.bind(0, "0.0.0.0");
		socket.addEventListener(flash.events.DatagramSocketDataEvent.DATA,onSocketData);
		socket.receive();
		c.safeSend( HELLO, haxe.io.Bytes.alloc(0) );
		c.flush(false,null);
		clients = [self];
		this.onConnect = onConnect;
		#else
		throw "Not implemented";
		#end
	}

	public function wait( host : String, port : Int, ?onConnected : NetworkClient -> Void ) {
		close();
		#if (flash && air3)
		socket = new flash.net.DatagramSocket();
		self = new UdpClient(this);
		socket.bind(port, host);
		socket.addEventListener(flash.events.DatagramSocketDataEvent.DATA,onSocketData);
		this.onNewClient = onConnected;
		socket.receive();
		isAuth = true;
		#else
		throw "Not implemented";
		#end
	}
	
	@:allow(hxd.net.UdpClient)
	function sendData( client : UdpClient, data : haxe.io.Bytes ){
		inline function _send(){
			var packet = haxe.io.Bytes.alloc(data.length+4);
			packet.setInt32(0,0xdeadce11);
			packet.blit(4,data,0,data.length);
			packet.setInt32(0,haxe.crypto.Crc32.make(packet));
			#if (flash && air3)
			socket.send( packet.getData(), 0, packet.length, client.ip, client.port );
			#end
		}
		
		#if (debug || networkConditioner)
		if( packetLossRatio > 0 && Math.random() < packetLossRatio )
			return;
		var delay = packetDelayMin + Math.random() * (packetDelayMax-packetDelayMin);
		if( delay > 0 )
			haxe.Timer.delay(function(){ _send(); },Std.int(delay*1000));
		else
		#end
		_send();
	}
	
	#if (flash && air3)	
	function onSocketData( event : flash.events.DatagramSocketDataEvent ){
		onData( haxe.io.Bytes.ofData(event.data), event.srcAddress, event.srcPort );
	}
	#end
	
	function onData( data : haxe.io.Bytes, srcIP : String, srcPort : Int ){
		if( data.length < 12 ){
			#if debug
			trace("Incomplete packet: "+data.toHex());
			#end
			return;
		}
		
		var crc = data.getInt32(0);
		data.setInt32(0,0xdeadce11);
		if( crc != haxe.crypto.Crc32.make(data) ){
			#if debug
			trace("CRC mismatch");
			#end
			return;
		}
		
		var client : UdpClient;
		var ck = null;
		if( !isAuth && self != null ){
			client = cast self;
		}else{
			ck = srcIP+":"+srcPort;
			client = mClients.get( ck );
		}
		
		var pktId = data.getUInt16(4);
		var firstType = data.get(12);
		var isNewClient = pktId == 1 && firstType == HELLO;
		if( client == null && !isNewClient ){
			#if debug
			trace("Client must send empty packet first");
			#end
			return;
		}else if( !isAuth && !connected && firstType == CONNECTED ){
			connected = true;
			onConnect( true );
			onConnect = null;
		}
		
 		if( isNewClient ){
			if( !isAuth ) return;
			if( client != null )
				client.stop();
			
			client = new UdpClient(this,srcIP,srcPort);
			mClients.set(ck,client);
			pendingClients.push( client );
			client.safeSend( CONNECTED, haxe.io.Bytes.alloc(0) );
			onNewClient(client);
		}
		
		client.readData(data,4);
	}
	
	override function fullSync( c : NetworkClient ){
		if( !pendingClients.remove(c) )
			return;

		// unique client sequence number
		var seq = clients.length + 1;
		while( true ) {
			var found = false;
			for( c in clients )
				if( c.seqID == seq ) {
					found = true;
					break;
				}
			if( !found ) break;
			seq++;
		}
		c.seqID = seq;

		clients.push(c);
		var refs = ctx.refs;
		ctx.begin();
		ctx.addByte(c.seqID);
		for( o in refs )
			if( o != null )
				ctx.addAnyRef(o);
		ctx.addAnyRef(null);
		
		(cast c:UdpClient).safeSend( FULLSYNC, ctx.flush() );
	}
	
	var curRPC : Int;
	override function beginRPC(o:NetworkSerializable, id:Int, onResult:Serializer->Void) {
		if( ctx.refs[o.__uid] == null )
			throw "Can't call RPC on an object not previously transferred";
			
		if( onResult != null ) {
			var id = rpcUID++;
			curRPC = RPC_WITH_RESULT;
			ctx.addInt(id);
			rpcWaits.set(id, onResult);
		} else
			curRPC = RPC;
		ctx.addInt(o.__uid);
		ctx.addByte(id);
		return ctx;
	}

	override function endRPC() {
		var b = ctx.flush();
		if( targetClient != null )
			(cast targetClient:UdpClient).safeSend( curRPC, b );
		else
			for( c in clients )
				(cast c:UdpClient).safeSend( curRPC, b );
	}
	
	override function sendMessage( msg : Dynamic, ?to : NetworkClient ) {
		var t;
		if( Std.is(msg, haxe.io.Bytes) ) {
			t = BMSG;
			ctx.addBytes(msg);
		} else {
			t = MSG;
			ctx.addString(haxe.Serializer.run(msg));
		}
		
		var b = ctx.flush();
		if( to == null )
			for( c in clients )
				(cast c:UdpClient).safeSend( t, b );
		else
			(cast to:UdpClient).safeSend( t, b );
	}
	
	override function makeAlive() {
		var objs = @:privateAccess ctx.newObjects;
		if( objs.length == 0 )
			return;
		while( true ) {
			var o = objs.shift();
			if( o == null ) break;
			var n = Std.instance(o, NetworkSerializable);
			if( n == null ) continue;
			n.__host = this;
			n.__lastChanges = new haxe.ds.Vector((untyped Type.getClass(o).__fcount));
			n.alive();
		}
		while( aliveEvents.length > 0 )
			aliveEvents.shift()();
	}
	
	override function register( o : NetworkSerializable ){
		if( ctx.refs[o.__uid] != null )
			return;
		if( !isAuth ) {
			var owner = o.networkGetOwner();
			if( owner == null || owner != self.ownerObject )
				throw "Can't register "+o+" without ownership (" + owner + " should be " + self.ownerObject + ")";
		}
		o.__host = this;
		o.__lastChanges = new haxe.ds.Vector((untyped Type.getClass(o).__fcount));
	
		unmark(o);
		ctx.addAnyRef(o);
		
		var b = ctx.flush();
		for( c in clients )
			(cast c:UdpClient).safeSend( REG, b );
	}
	
	override function unregister( o : NetworkSerializable ){
		if( o.__host == null )
			return;
		if( !isAuth ) {
			var owner = o.networkGetOwner();
			if( owner == null || owner != self.ownerObject )
				throw "Can't unregister "+o+" without ownership (" + owner + " should be " + self.ownerObject + ")";
		}
		o.__host = null;
		o.__bits = 0;
		o.__lastChanges = null;
		unmark(o);
		
		ctx.refs.remove(o.__uid);
		ctx.addInt(o.__uid);
		var b = ctx.flush();
		for( c in clients )
			(cast c:UdpClient).safeSend( UNREG, b );
	}
	
	override function flushProps(){
		var o = markHead;
		while( o != null ) {
			if( o.__bits != 0 ) {
				var b = curChanges.get(o.__uid);
				curChanges.set( o.__uid, (b==null ? 0 : b) | o.__bits );
				var i = 0;
				while( 1 << i <= o.__bits ) {
					if( o.__bits & (1 << i) != 0 )
						o.__lastChanges[i] = tick;
					i++;
				}
				
				ctx.addInt(o.__uid);
				var old = @:privateAccess ctx.out;
				@:privateAccess ctx.out = new haxe.io.BytesBuffer();
				o.networkFlush(ctx);
				var b = @:privateAccess ctx.out.getBytes();
				@:privateAccess ctx.out = old;
				ctx.addBytes(b);
				//trace("Flush Object#"+o.__uid+": "+b.length+" ("+b.get(0)+")");
				hasData = true;
			}
			var n = o.__next;
			o.__next = null;
			o = n;
		}
		markHead = null;
	}
	
	override function flush(){
		if( isAuth || connected ){
			flushProps();
		}
		var syncProps = hasData ? ctx.flush() : null;
		
		if( isAuth )
			for( c in mClients )
				c.flush( isAuth||connected, syncProps );
		else if( self != null )
			(cast self:UdpClient).flush( isAuth||connected, syncProps );
		
		curChanges = new Map();
	}
	
}