package h2d;

enum BlendMode {
	Normal;
	None;
	Add;
	SoftAdd;
	Multiply;
	Erase;
	Hide;
	
	NormalPremul; // or load using hxd.res.Image to get rid of flash premultiplication !
}