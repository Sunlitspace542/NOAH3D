# Wolf3D/Noah3D SNES Sound Driver

This is the Wolf3D SNES sound driver source code, converted to be assembled with Asar. Run `make.bat` to assemble.

Outputs `DRIVER.BIN`, which should be a 1:1 match to `NOAH3D\SOUND\DRIVER`.

## ARAM Map
```
$0000-$0013 - Sound driver variables
$01FF - Stack pointer
$0200-$037A - Sound driver code
$0600 - Sample directory; 64 entries consisting of 1 word start addr, 1 word loop point
$0700 - Start of sample data
```