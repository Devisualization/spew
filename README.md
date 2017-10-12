# System Propagation of Event Wells (S.P.E.W.)

	' Not spew,' said Alphaglosined impatiently. 'It's S-P-E-W. Stands for the System Propagation of Event Wells.'

So what is an Event Well, you may ask. Well good question.
I don't quite know, but it has something to do with creating events at a higher level then the system that created them and propergating them to a nice user (developer) interface.

In the end what exactly are the goals for S.P.E.W?
Well not much, just a unified event loop, bindings and of course interfacing to OS constructs that can have major performance impact like windowing.

So why should we take you seriously? After all glib exists. Well, you're still reading this aren't you.

## Platform support
- Windows 7+ (tested on Windows 10 officially only)

Depends upon libuv for sockets+timer support.
Can load+extract from a [Nuget]() package. Thie linked packed is fat, meaning it should work on Linux, OSX and Windows.

## Tasks

- [ ] General structure
- [ ] Event loop
  - [x] Abstraction
  - [x] Basic implementation
  - [ ] Wells:
    - [ ] X11
    - [x] WinAPI
    - [ ] Cocoa
	- [x] LibUV
  - [ ] Consumers:
    - [ ] X11
    - [x] WinAPI
    - [ ] Cocoa
- [ ] Streams
	- [x] TCP
		- [x] Client
		- [x] Server
	- [ ] UDP
			I hate sockets with a passion - alphaglosined
		If you wish to finish implementation [Be Our Guest](https://www.youtube.com/watch?v=hIKhoEIBSxU), a good portion of the TCP code can be reused for UDP.
		- [ ] Client
		- [ ] Server
- [ ] Threading
- [ ] File system
- [ ] Timer
- [ ] Windowing
  - [ ] X11
    - [ ] Core
    - [ ] Features:
       - [ ] notifications
       - [ ] cursor
       - [ ] icon
       - [ ] menu
       - [ ] screenshot
    - [ ] Contexts:
       - [ ] VRAM
       - [ ] OpenGL
       - [ ] Vulkan
  - [x] WinAPI
    - [ ] Core
    - [x] Features:
       - [x] notifications
       - [x] cursor
       - [x] icon
       - [x] menu
       - [x] screenshot
    - [ ] Contexts:
       - [x] VRAM
       - [x] OpenGL
       - [ ] DirectX
       - [ ] Vulkan
  - [ ] Cocoa
    Contexts:
    - [ ] VRAM
    - [ ] OpenGL
    - [ ] Vulkan

## License
Boost
