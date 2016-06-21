package hxd.net;
import hxd.net.NetworkHost;

typedef SafeChunk = {
	var idx : Int;
	var bytes : haxe.io.Bytes;
};

typedef PacketData = {
	var id : Int;
	var tick : Int;
	var sent : Float;
	var changes : Map<Int,Int>;
	var safeChunks : Array<SafeChunk>;
};

// Packet structure
// CRC     4 [crc32]
// GLOBAL 11 [packetId:16][lastAck:16][ackSeq:32][tick:24]
// SUBPKT  2 [type:4][len:12]
// PKT SYNC [data...]
// PKT SAFE [id:16][data...]

class UdpClient extends NetworkClient {
	
	inline static var SYNC = 1;
	inline static var SAFE = 2;

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
	var ack : Array<Int>;
	var rSafeIndex : Int;
	var rSafeBuffer : Map<Int,haxe.io.Bytes>;
	
	
	public function new(host,ip:String=null,port:Int=0) {
		super(host);
		this.ip = ip;
		this.port = port;
		this.pktId = 0;
		this.ack = [];
		this.rtt = -1.0;
		this.sentPackets = new Map();
		this.sSafeBuffer = [];
		this.sSafeIndex = 0;
		this.rSafeBuffer = new Map();
		this.rSafeIndex = 0;
	}
	
	function onAck( pktId : Int ){
		var pkt = sentPackets.get( pktId );
		if( pkt == null )
			return;
		var tt = haxe.Timer.stamp() - pkt.sent;
		rtt = (rtt < 0) ? tt : (rtt * 9 + tt) * 0.1;
		sentPackets.remove( pktId );
	}
	
	function doProcessMessage( buffer : haxe.io.Bytes, pos : Int, end : Int ){
		while( pos < end ) {
			var oldPos = pos;
			pos = processMessage(buffer, pos);
			if( host.checkEOM && buffer.get(pos++) != NetworkHost.EOM )
				throw "Message missing EOM " + buffer.sub(oldPos, pos - oldPos).toHex()+"..."+(buffer.sub(pos,hxd.Math.imin(end-pos,128)).toHex());
		}
	}
	
	function processSafeData( id : Int, bytes : haxe.io.Bytes ){
		if( id == rSafeIndex ){
			doProcessMessage(bytes,0,bytes.length);
			rSafeIndex++;
			while( rSafeBuffer.exists(rSafeIndex) ){
				var bytes = rSafeBuffer.get(rSafeIndex);
				rSafeBuffer.remove(rSafeIndex);
				doProcessMessage(bytes,0,bytes.length);
				rSafeIndex++;
			}
		}else{
			rSafeBuffer.set( id, bytes );
		}
	}
	
	public function readData( buffer : haxe.io.Bytes, pos : Int ) {
		var input = new haxe.io.BytesInput(buffer);
		input.position = pos;
		
		var id = input.readUInt16();
		ack.push( id );
		
		var lastAck = input.readUInt16();
		var ackSeq = input.readInt32();
		var tick = input.readUInt24();
		var ctx = host.ctx;
		ctx.tick = tick;
		if( lastAck != 0 ){
			onAck( lastAck );
			for( i in 0...32 ){
				if( ackSeq & (1<<i-1) != 0 )
					onAck( lastAck - i );
			}
		}
		
		while( input.position < buffer.length - 2 ){
			var sp = input.readUInt16();
			var type = sp>>12;
			var len = sp&0xFFF;
			
			switch( type ){
				case SAFE:
					var safeId = input.readUInt16();
					var data = haxe.io.Bytes.alloc(len-2);
					input.readBytes(data,0,len-2);
					processSafeData( safeId, data );
				case SYNC:
					doProcessMessage(buffer,input.position,input.position+len);
					input.position += len;
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
				ctx.addByte(NetworkHost.SYNC);
				ctx.addInt(o.__uid);
				o.networkFlush(ctx);
				if( host.checkEOM ) ctx.addByte(NetworkHost.EOM);
				o.__bits = obits;
			}
		}
		if( pkt.safeChunks != null )
			for( c in pkt.safeChunks )
				sSafeBuffer.push( c );
	}
	
	@:allow(hxd.net.UdpHost)
	function safeSend( bytes : haxe.io.Bytes ){
		sSafeBuffer.push({idx: sSafeIndex++, bytes: bytes});
	}
	
	public function flush(){
		if( sSafeBuffer.length > 0 )
			send( haxe.io.Bytes.alloc(0) );
	}

	override function send( bytes : haxe.io.Bytes ) {
		checkPacketLost();
		@:privateAccess {
			if( host.ctx.out.length > 0 ){
				var oBytes = bytes;
				var aBytes = host.ctx.out.getBytes();
				host.ctx.out = new haxe.io.BytesBuffer();
				bytes = haxe.io.Bytes.alloc( oBytes.length + aBytes.length );
				bytes.blit(0,oBytes,0,oBytes.length);
				bytes.blit(oBytes.length,aBytes,0,aBytes.length);
			}
		}
		
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
		
		if( bytes.length == 0 && safeChunks == null )
			return;
		
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
			lastAck = ack[ack.length-1];
			var r = 0;
			for( i in 0...ack.length-1 ){
				var v = ack[i];
				if( v < lastAck - 32 )
					r++;
				else
					ackSeq |= 1<<(lastAck-v);
			}
			if( r > 0 )
				ack.splice(0,r);
		}
		pk.writeUInt16(pktId);
		pk.writeUInt16(lastAck);
		pk.writeInt32(ackSeq);
		pk.writeUInt24(tick);
		if( safeChunks != null ){
			for( c in safeChunks ){
				pk.writeUInt16( SAFE<<12 | ((c.bytes.length+2)&0xFFF) );
				pk.writeUInt16( c.idx );
				pk.writeBytes( c.bytes, 0, c.bytes.length );
			}
		}
		if( bytes.length > 0 ){
			pk.writeUInt16( SYNC<<12 | (bytes.length&0xFFF) );
			pk.writeBytes(bytes,0,bytes.length);
		}
		
		h.sendData(this,pk.getBytes());
	}

	public function toString(){
		return "UdpClient("+ip+":"+port+")";
	}

}



class UdpHost extends NetworkHost {
	
	public var tick : Int;

	var connected = false;
	var onNewClient : UdpClient -> Void;
	var mClients : Map<String,UdpClient>;
	#if (flash && air3)
	var socket : flash.net.DatagramSocket;
	#end
	
	@:allow(hxd.net.UdpClient)
	var curChanges : Map<Int,Int>;
	
	#if debug
	public var packetLossRatio = 0.0;
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
	}
	
	// TODO : manage pendingClients / clients / onConnect()
	public function connect( host : String, port : Int, ?onConnect : Bool -> Void ) {
		#if (flash && air3)
		close();
		socket = new flash.net.DatagramSocket();
		self = new UdpClient(this,host,port);
		socket.bind(0, "0.0.0.0");
		socket.addEventListener(flash.events.DatagramSocketDataEvent.DATA,onSocketData);
		socket.receive();
		sendData(cast self,haxe.io.Bytes.alloc(0)); // TODO define this packet as a reliable packet (to enable auto ordering & retry on packet loss)
		connected = true;
		clients = [self];
		onConnect( true );
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
		#if debug
		if( packetLossRatio > 0 && Math.random() < packetLossRatio )
			return;
		#end
		var packet = haxe.io.Bytes.alloc(data.length+4);
		packet.setInt32(0,0xdeadce11);
		packet.blit(4,data,0,data.length);
		packet.setInt32(0,haxe.crypto.Crc32.make(packet));
		#if (flash && air3)
		socket.send( packet.getData(), 0, packet.length, client.ip, client.port );
		#end
	}
	
	#if (flash && air3)	
	function onSocketData( event : flash.events.DatagramSocketDataEvent ){
		onData( haxe.io.Bytes.ofData(event.data), event.srcAddress, event.srcPort );
	}
	#end
	
	function onData( data : haxe.io.Bytes, srcIP : String, srcPort : Int ){
		var crc = data.getInt32(0);
		data.setInt32(0,0xdeadce11);
		if( crc != haxe.crypto.Crc32.make(data) ){
			#if debug
			trace("CRC MISMATCH");
			#end
			return;
		}
		
		var client : UdpClient;
		var ck = null;
		if( connected && !isAuth ){
			client = cast self;
		}else{
			ck = srcIP+":"+srcPort;
			client = mClients.get( ck );
		}
		
		if( client == null && data.length > 4 ){
			#if debug
			trace("Client must send empty packet first");
			#end
			return;
		}
		
		
		if( data.length == 4 ){
			if( !isAuth ) return;
			if( client != null ){
				//client.close();
				clients.remove( client );
				pendingClients.remove( client );
			}
			client = new UdpClient(this,srcIP,srcPort);
			mClients.set(ck,client);
			pendingClients.push( client );
			onNewClient(client);
		}else{
			client.readData(data,4);
		}
	}
	
	var oldOut : haxe.io.BytesBuffer;
	override function beginRPC(o:NetworkSerializable, id:Int, onResult:Serializer->Void) {
		if( ctx.refs[o.__uid] == null )
			throw "Can't call RPC on an object not previously transferred";
			
		oldOut = @:privateAccess ctx.out;
		@:privateAccess ctx.out = new haxe.io.BytesBuffer();
		
		if( onResult != null ) {
			var id = rpcUID++;
			ctx.addByte(NetworkHost.RPC_WITH_RESULT);
			ctx.addInt(id);
			rpcWaits.set(id, onResult);
		} else
			ctx.addByte(NetworkHost.RPC);
		ctx.addInt(o.__uid);
		ctx.addByte(id);
		if( logger != null )
			logger("RPC " + o +"."+o.networkGetName(id,true)+"()");
		return ctx;
	}

	override function endRPC() {
		if( checkEOM ) ctx.addByte(NetworkHost.EOM);
		
		var b = @:privateAccess ctx.out.getBytes();
		@:privateAccess ctx.out = oldOut;
		oldOut = null;
		for( c in clients )
			(cast c:UdpClient).safeSend( b );
	}
	
	override function sendMessage( msg : Dynamic, ?to : NetworkClient ) {
		var old = @:privateAccess ctx.out;
		@:privateAccess ctx.out = new haxe.io.BytesBuffer();
		
		if( Std.is(msg, haxe.io.Bytes) ) {
			ctx.addByte(NetworkHost.BMSG);
			ctx.addBytes(msg);
		} else {
			ctx.addByte(NetworkHost.MSG);
			ctx.addString(haxe.Serializer.run(msg));
		}
		if( checkEOM ) ctx.addByte(NetworkHost.EOM);
		
		var b = @:privateAccess ctx.out.getBytes();
		@:privateAccess ctx.out = old;
		if( to == null )
			for( c in clients )
				(cast c:UdpClient).safeSend( b );
		else
			(cast to:UdpClient).safeSend( b );
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
	
		var old = @:privateAccess ctx.out;
		@:privateAccess ctx.out = new haxe.io.BytesBuffer();
		unmark(o);
		ctx.addByte(NetworkHost.REG);
		ctx.addAnyRef(o);
		if( checkEOM ) ctx.addByte(NetworkHost.EOM);
		
		var b = @:privateAccess ctx.out.getBytes();
		@:privateAccess ctx.out = old;
		for( c in clients )
			(cast c:UdpClient).safeSend( b );
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
		@:privateAccess {
			var old = ctx.out;
			ctx.out = new haxe.io.BytesBuffer();
			ctx.addByte(NetworkHost.UNREG);
			ctx.addInt(o.__uid);
			if( checkEOM ) ctx.addByte(NetworkHost.EOM);
			var b = ctx.out.getBytes();
			ctx.out = old;
			for( c in clients )
				(cast c:UdpClient).safeSend( b );
		}
	}
	
	override function flushProps(){
		ctx.tick = tick;		
		var o = markHead;
		while( o != null ) {
			if( o.__bits != 0 ) {
				var b = curChanges.get(o.__uid);
				curChanges.set( o.__uid, (b==null ? 0 : b) | o.__bits );
				var i = 0;
				while( 1 << i <= o.__bits ) {
					if( o.__bits & (1 << i) != 0 )
						o.__lastChanges[i] = ctx.tick;
					i++;
				}
				
				if( logger != null ) {
					var props = [];
					var i = 0;
					while( 1 << i <= o.__bits ) {
						if( o.__bits & (1 << i) != 0 )
							props.push(o.networkGetName(i));
						i++;
					}
					logger("SYNC " + o + "#" + o.__uid + " " + props.join("|"));
				}
				ctx.addByte(NetworkHost.SYNC);
				ctx.addInt(o.__uid);
				o.networkFlush(ctx);
				if( checkEOM ) ctx.addByte(NetworkHost.EOM);
				hasData = true;
			}
			var n = o.__next;
			o.__next = null;
			o = n;
		}
		markHead = null;
	}
	
	override function flush(){
		super.flush();
		curChanges = new Map();
		
		if( isAuth )
			for( c in mClients )
				c.flush();
		else if( self != null )
			(cast self:UdpClient).flush();
	}
	
}