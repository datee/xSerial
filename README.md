# xSerial
Serial communication for Haxe / C++

This is a quick library for serial communication in [Haxe](http://haxe.org). 
It only works with the C++ target and Windows (for now). But i might add support for Linux / Mac also.

It is based upon hxSerial from Andy Li : https://github.com/andyli/hxSerial.
However it does not need any dll or external dependencies to work.

Its still a bit ugly work-in-progress and hopefully will be be somewhat improved!

**To use:**
```haxe
var serial = new Serial("COM8", 9600);
if (serial.isSetup)
{
	if (serial.available() > 0)
	{
		var data:String = serial.readBytes(serial.available());
		serial.flush();
	}
}
```
### Methods available
```haxe
readBytes(length:Int):String;
readByte():Null<Int>;
writeBytes(length:Int,data:String):Bool;
writeByte(data:Int):Bool;
available():Int;
flush(?flushIn:Bool, ?flushOut);

static enumerateDevices():Array<ComDevice>;
```
### Info

Only tested on Windows 10, Haxe 4.0.5



