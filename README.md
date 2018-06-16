# System Propagation of Event Wells (S.P.E.W.)

	' Not spew,' said Alphaglosined impatiently. 'It's S-P-E-W. Stands for the System Propagation of Event Wells.'

So what is an Event Well, you may ask. Well good question.
I don't quite know, but it has something to do with creating events at a higher level then the system that created them and propagating them to a nice user (developer) interface.

In the end what exactly are the goals for S.P.E.W?
Well not much, just a unified event loop, bindings and of course interfacing to OS constructs that can have major performance impact like windowing.

So why should we take you seriously? After all glib exists. Well, you're still reading this aren't you.

## Platform support
- Windows 7+ (tested on Windows 10 officially only)

Depends upon LibUV for sockets+timer+file watcher support.
Can load+extract from a [Nuget]() package. The linked packed is fat, meaning it should work on Linux, OSX and Windows.

Warning: Windows 64bit for dmd is currently bugged when using the diagnostic code. OpenGL bindings is too large for debug information.

## Tasks

- [ ] General structure
- [ ] Event loop
  - [x] Abstraction
  - [x] Basic implementation
  - [ ] Wells:
    - [x] X11
    - [x] WinAPI
    - [ ] Cocoa
	- [x] LibUV
    - [x] GLIB
  - [ ] Consumers:
    - [x] X11
    - [x] WinAPI
    - [ ] Cocoa
- [x] Streams
	- [x] TCP
		- [x] Client LibUV
		- [ ] Client Fallback
		- [x] Server LibUV
		- [ ] Server Fallbak
	- [x] UDP
		- [x] Local LibUV
		- [ ] Local Fallback
		- [x] Remote LibUV
		- [ ] Remote Fallback
- [ ] Threading
- [x] File system
  - [x] Watcher
      - [x] LibUV
      - [ ] Fallback?
- [x] Timer
  - [x] WinAPI
  - [x] LibUV
  - [ ] Fallback
- [ ] Windowing
  - [ ] X11
    - [x] Core
    - [ ] Features:
       - [ ] notifications
       - [x] cursor
       - [x] icon
       - [x] screenshot
       - [x] Clipboard
       - [x] Drag&Drop
    - [x] Contexts:
       - [x] VRAM
       - [x] OpenGL
  - [x] WinAPI
    - [x] Core
    - [x] Features:
       - [x] notifications
       - [x] cursor
       - [x] icon
       - [x] menu
       - [x] screenshot
       - [x] Clipboard
       - [x] Drag&Drop
    - [x] Contexts:
       - [x] VRAM
       - [x] OpenGL
  - [ ] Cocoa
    - [ ] Core
    - [ ] Features:
       - [ ] notifications
       - [ ] cursor
       - [ ] icon
       - [ ] menu
       - [ ] screenshot
       - [ ] Clipboard
       - [ ] Drag&Drop
    - [ ] Contexts:
       - [ ] VRAM
       - [ ] OpenGL

__Short list of won't-implement__:
- Contexts
	- DirectX
	- Vulkan
	- Metal

## License
Boost
