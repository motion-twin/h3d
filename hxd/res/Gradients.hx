package hxd.res;

class Gradients extends Resource {
	public function toMap() : hxd.fmt.grd.Data {
		return (new hxd.fmt.grd.Reader(new FileInput(entry))).read();
	}
}