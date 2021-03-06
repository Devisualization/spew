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
    - [x] Poll (posix)
    - [x] Epoll (linux)
    - [x] D-Bus (system-d)
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
- [x] File system
  - [x] Watcher
      - [x] LibUV
      - [ ] Fallback
- [x] Timer
  - [x] WinAPI
  - [x] LibUV
  - [ ] Fallback
- [ ] Windowing
  - [x] X11
    - [x] Core
    - [x] Features:
       - [x] notifications
          - [x] FreeDesktop
          - [x] D-Bus org.freedesktop.Notifications
       - [x] cursor
       - [x] icon
       - [x] screenshot
       - [x] Clipboard
       - [x] Drag&Drop
    - [x] Contexts:
       - [x] VRAM
       - [x] OpenGL
    - [ ] Robot
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
    - [x] Robot
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
    - [ ] Robot

Warning:
- For X11 under e.g. KDE you won't get a notification window support. You must create an external [config](https://forum.kde.org/viewtopic.php?f=305&t=142838) file to make it appear.

__Short list of won't-implement__:
- Contexts
	- DirectX
	- Vulkan
	- Metal
- Input
	- Game controllers, I suggest you to use a library like [libstem_gamepad](https://github.com/ThemsAllTook/libstem_gamepad) or [NVGamepad](https://developer.nvidia.com/cross-platform-gamepad-api).
- Audio, I suggest you use [Port Audio](http://portaudio.com) or [libsoundio](http://libsound.io/).

## License
Boost
