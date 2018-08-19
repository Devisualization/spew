module diagnostic;

import core.time : Duration, dur;
import std.datetime : msecs;
import stdx.allocator;

import devisualization.util.core.memory.managed;
import devisualization.bindings.opengl;

import cf.spew.instance;
import cf.spew.events.defs;
import cf.spew.events.windowing;
import cf.spew.event_loop.defs;
import cf.spew.event_loop.base;
import cf.spew.streams;
import cf.spew.ui;
import cf.spew.ui.features.clipboard;
import cf.spew.miscellaneous;

enum : bool {
    Enable_Test_Window = true,
    Enable_Test_TCP = true,
    Enable_Test_UDP = true,
    Enable_Test_FileSystemWatch = true,
    Enable_Test_NotificationWindow = true,

    Enable_Kill_Window = true,
    Enable_Kill_TCP_Client = false,
    Enable_Kill_TCP_Server = false,
    Enable_Kill_UDP = false,
    Enable_Kill_FileSystemWatch = false,

    Enable_Window_GL = true,
    Enable_Force_Kill_Window = false,
}

// \/ global state

// | \/ streams
managed!ISocket_TCP tcpClientEndPoint;
managed!ISocket_TCPServer tcpServer;
managed!ISocket_UDPLocalPoint udpLocalPoint;
// | /\ streams
// | \/ notifications

managed!IWindow notificationWindow;

// | /\ notifications
// | \/ windowing
managed!IWindow window;
managed!ITimer windowForceDrawTimer;

static if (Enable_Window_GL) {
    /*
     * Both of GL and OpenGL_Loader are rather sensitive to where they are placed in memory.
     * So both are allocated on the heap.
     */
    GL* gl;
    OpenGL_Loader!OpenGL_Context_Callbacks* oglLoader;
    bool openglContextCreated, openglObjectsCreated;
    GLuint vertexShaderGL, fragmentShaderGL, programGL, vertexbufferGL, vertexArrayGL;
    GLint resultGL, infoLogLengthGL;
}
// | /\ windowing
// | \/ FS watching

managed!IFileSystemWatcher testDirFileSystemWatcher;

// | /\ FS watching

// /\ global state

int main() {
    version(all) {
        import std.stdio : writeln;

        writeln("Hello there!");
        writeln("Now lets do a quick diagnostic on the platform...");
        writeln;
        writeln("It was built on ", __TIMESTAMP__, " using ", __VENDOR__, " compiler ", __VERSION__, ".");

        if (Instance.current is null) {
            writeln;
            writeln("Well that is odd, there is no implementation defined.");
            writeln("Please compile in spew:implementation or provide your own implementation.");
            writeln("Check http://code.dlang.org for more compatible implementations");
            writeln(" or have a look on the NewsGroup! http://forum.dlang.org/group/announce");

            return -1;
        }

        version(Have_spew_implementation) {
            writeln("I see you have compiled with spew:implementation enabled, good choice!");

            if (Instance.current !is Instance.theDefault) {
                writeln;
                writeln("Oh and you even have your own implementation well done!");
                writeln("But feel free to remove spew.implementation from compilation");
                writeln(" if you want smaller binaries as it is not being used");
                writeln(" ...at least in terms of cf.spew.instance abstraction.");
            }
        } else {
            writeln;
            writeln("So no idea where this implementation comes from, but that is ok.");
            writeln("That just means you've been smart and got your own one");
            writeln(" and not using the one provided with S.P.E.W. spew:implementation.");
        }

        if (Instance.current.eventLoop is null) {
            writeln;
            writeln("Andddd it appears that the event loop implementation is not all ok");
            writeln(" as it doesn't even exist.");
            return -2;
        } else if (Instance.current.eventLoop.manager is null) {
            writeln;
            writeln("Well this is strange, the event loop manager itself");
            writeln(" doesn't quite seem to exist, yet there is event loop support");
            writeln(" suposadly existing for this implementation.");
            return -3;
        }

        if (Instance.current.ui is null) {
            writeln;
            writeln("Ok well this is awkward but you haven't got a very user friendly");
            writeln(" implementation compiled in.");
            writeln("No really, it has no user interface support!");
            return -4;
        } else if (Instance.current.ui.primaryDisplay().isNull) {
            writeln;
            writeln("Just because we can, we looked to see if there was a display");
            writeln(" as it turns out, there are none.");
            writeln("Because this is a diagnostic, I am going to assume this is a problem.");
            return -5;
        }

        if (Instance.current.streams is null) {
            writeln;
            writeln("The implementation seems to be missing stream support.");
            writeln("This is quite a problem if you want to open up a socket.");
            return -6;
        } else if (Instance.current.streams.allLocalAddress().isNull) {
            writeln;
            writeln("Weird, we have stream support.");
            writeln("Yet it cannot get a list of network interfaces that the system has");
            writeln(" not even loop back!");
            return -7;
        }

        Instance.current.ui.clipboardText = "Hi from SPEW!";
        auto gottenClipboardText = Instance.current.ui.clipboardText();
    	
        if (gottenClipboardText[] == "Hi from SPEW!") {
            writeln;
            writeln("Clipboard UI support is working as intended");
        } else {
            writeln;
            writeln("Clipboard UI support is not working.");
            writeln("This may not be an error, as it is an optional feature.");
        }

        writeln;
        writeln("Right so far everything looks all good and dandy.");
        writeln("But it would be nice to have more features needed to be testing!");

        writeln;
        writeln("Exporting event loop manager rules:");
        try {
            string text = Instance.current.eventLoop.manager.describeRules();
            writeln("{#####################################{");
            writeln(text);
            writeln("}#####################################}");
        } catch(Error e) {
            writeln("Failed, might not be implemented...");
            writeln("{#####################################{");
            writeln(e);
            writeln("}#####################################}");
        }

        writeln("So it looks like:");
        writeln("\t- Event loop");
        writeln("\t- User interface");
        writeln("\t\t- Clipboard");
        writeln("\t- Stream (sockets)");
        writeln("are all provided and functioning possibly.");

        writeln;
        writeln("Continuing on to more resillient tests...");

        static if (Enable_Test_TCP) {
            writeln;
            writeln("TCP server:");
            aSocketTCPServerCreate();
    	
            writeln;
            writeln("TCP client:");
            aSocketTCPClientCreate();
        }

        static if (Enable_Test_UDP) {
            writeln;
            writeln("UDP:");
            aSocketUDPCreate();
        }

        static if (Enable_Test_Window) {
            writeln;
            writeln("Window handling:");
            aWindowTest();
        }

        static if (Enable_Test_FileSystemWatch) {
            writeln;
            writeln("File system watching");
            fileSystemWatcherCreate();
        }

        static if (Enable_Test_NotificationWindow) {
            writeln;
            writeln("Notification window");
            notificationTrayTest();
        }
    }

    // normally 3s would be ok for a timeout, but ugh with sockets, not so much!
    static if (Enable_Test_TCP || Enable_Test_UDP) {
        Instance.current.eventLoop.manager.setSourceTimeout(30.msecs);
    }

    // Idle callback job is to give the kernel a chance to give other
    //  processes/threads cpu time.
    // After all, do we REALLY need all of it?
    // Maybe for a game, but say a GUI toolkit? Nope.
    // This is make or break code for non-Windows platforms.
    Instance.current.eventLoop.manager.setIdleCallback = () {
        writeln("idle callback");

        import core.thread : Thread;
        Thread.sleep(dur!"msecs"(30));
    };

    Instance.current.eventLoop.execute();
    return 0;
}

void fileSystemWatcherCreate() {
    import std.file : write, remove, exists, mkdir;

    if (!exists("testdirFSwatch")) {
        mkdir("testdirFSwatch");
    }

    testDirFileSystemWatcher = Instance.current.misc.createFileSystemWatcher("testdirFSwatch");
    testDirFileSystemWatcher.onCreate = (scope watcher, scope filename) {
        import std.stdio : writeln, stdout;
        writeln("File system watcher [", watcher.path, "]: create ", filename);stdout.flush;
    };
    testDirFileSystemWatcher.onDelete = (scope watcher, scope filename) {
        import std.stdio : writeln, stdout;
        writeln("File system watcher [", watcher.path, "]: delete ", filename);stdout.flush;

        static if (Enable_Kill_FileSystemWatch) {
            Instance.current.eventLoop.stopAllThreads;
        }
    };
    testDirFileSystemWatcher.onChange = (scope watcher, scope filename) {
        import std.stdio : writeln, stdout;
        writeln("File system watcher [", watcher.path, "]: change ", filename);stdout.flush;
    };

    write("testdirFSwatch/test.txt", "Hi there!");
    remove("testdirFSwatch/test.txt");
}

// | \/ streams

void aSocketTCPClientCreate() {
    import std.socket : InternetAddress;
    import std.stdio : write, stdout;
    import core.time : dur;
	
    tcpClientEndPoint = Instance.current.streams.tcpConnect(new InternetAddress("127.0.0.1", 50968));
    tcpClientEndPoint.onData = (scope client, scope data) {
        write(cast(string)data); stdout.flush;
        return true;
    };
    tcpClientEndPoint.onStreamClose = (scope IStreamThing conn) {
        import std.stdio : writeln;
        writeln("closed tcp client");
        tcpClientEndPoint = managed!ISocket_TCP.init;

        static if (Enable_Kill_TCP_Client) {
            Instance.current.eventLoop.stopAllThreads;
        }
    };
    tcpClientEndPoint.onConnect = (scope IStreamEndPoint conn) {
        tcpClientEndPoint.write(cast(ubyte[])"
GET / HTTP/1.1\r
Host: cattermole.co.nz\r
\r
\r\n"[1 .. $]);
    };
}

void aSocketTCPServerCreate() {
    import std.socket : InternetAddress;
    import std.stdio : write, stdout;

    tcpServer = Instance.current.streams.tcpServer(new InternetAddress("127.0.0.1", 50968));
    tcpServer.onServerConnect = (scope IStreamServer server, scope IStreamEndPoint conn) {
        if (ISocket_TCP tcpClient = cast(ISocket_TCP)conn) {
            tcpClient.onData = (scope conn, scope data) {
                if (ISocket_TCP tcpClient = cast(ISocket_TCP)conn) {
                    tcpClient.write(data);
                }
                write("TCP:\t", cast(char[])data);stdout.flush;
                tcpServer.close();
                return true;
            };
        }
    };
    tcpServer.onStreamClose = (scope IStreamThing conn) {
        import std.stdio : writeln;
        writeln("closed tcp server");
        tcpServer = managed!ISocket_TCPServer.init;

        static if (Enable_Kill_TCP_Server) {
            Instance.current.eventLoop.stopAllThreads;
        }
    };
}

void aSocketUDPCreate() {
    import std.socket : InternetAddress;
    import std.stdio : write, stdout;

    udpLocalPoint = Instance.current.streams.udpLocalPoint(new InternetAddress("127.0.0.1", 30486));
    udpLocalPoint.onData =  (scope conn, scope data) {
        if (ISocket_UDPEndPoint udpEndPoint = cast(ISocket_UDPEndPoint)conn) {
        }

        write("UDP:\t", cast(char[])data);stdout.flush;
        conn.close();

        static if (Enable_Kill_UDP) {
            Instance.current.eventLoop.stopAllThreads;
        }

        return true;
    };

    auto remote = udpLocalPoint.connectTo(new InternetAddress("127.0.0.1", 30486));
    remote.write(cast(ubyte[])"Hi there!\nSome text via UDP.");
}

// | /\ streams
// | \/ notifications

void notificationTrayTest() {
    import cf.spew.ui.context.features.vram;
    import std.stdio : writeln, stdout;

    import devisualization.image.storage.base;
    import devisualization.image.interfaces;
    import std.experimental.color : RGBA8;

    auto icon = imageObject!(ImageStorageHorizontal!RGBA8)(2, 2);
    icon[0, 0] = RGBA8(255, 0, 0, 255);
    icon[1, 0] = RGBA8(0, 255, 0, 255);
    icon[0, 1] = RGBA8(0, 0, 255, 255);
    icon[1, 1] = RGBA8(255, 255, 255, 255);

    auto creator = Instance.current.ui.createWindow();
    if (creator.isNull) return;

    creator.style = WindowStyle.NoDecorations;
    creator.assignVRamContext;
    creator.size = vec2!ushort(cast(short)100, cast(short)200);
    creator.icon = icon;

    notificationWindow = creator.createWindow();

    Instance.current.ui.notify(cast(shared(ImageStorage!RGBA8))null, "Testing", "here");
    if (notificationWindow.isNull) return;

    notificationWindow.events.onVisible = () {
        writeln("onVisible:: notification tray flyout");
        stdout.flush;

        Instance.current.ui.notify(cast(shared(ImageStorage!RGBA8))null, "Hi!", "my text here");
    };

    notificationWindow.events.onInvisible = () {
        writeln("onInvisible:: notification tray flyout");
        stdout.flush;
    };

    Instance.current.ui.notificationTrayWindow = notificationWindow;
}

// | /\ notifications
// | \/ windowing

float[] opengl_example_vertex_bufferdata = [
    -1.0f, -1.0f, 0.0f,
    1.0f, -1.0f, 0.0f,
    0.0f,  1.0f, 0.0f
];

string VertexShaderGL_Source = "
#version 330 core
layout(location = 0) in vec3 pos;

void main() {
    gl_Position.xyz = pos;
    gl_Position.w = 1.0;
}
\0";

string FragmentShaderGL_Source = "
#version 330 core
out vec3 color;

void main() {
  color = vec3(1,0,0);
}
\0";

/*
 * The below code as designed, is meant to be hacked.
 * No single variation will be good enough.
 * 
 * Different contexts, window states (e.g. full screen) and menu
 *  is just the start of what is required.
 * Best to hack it into a form to confirm/deny a hypothesis.
 */
void aWindowTest() {
    import cf.spew.instance;
    import std.stdio : writeln, stdout;

    auto creator = Instance.current.ui.createWindow();
    if (creator.isNull) return;

    //creator.style = WindowStyle.NoDecorations;
    //creator.style = WindowStyle.Dialog;
    //creator.style = WindowStyle.Borderless;
    //creator.style = WindowStyle.Fullscreen;
    //creator.style = WindowStyle.Popup;

    creator.size = vec2!ushort(cast(short)800, cast(short)600);
    creator.assignMenu;

    static if (Enable_Window_GL) {
        gl = new GL;
        oglLoader = new OpenGL_Loader!OpenGL_Context_Callbacks(gl);
        creator.assignOpenGLContext(OpenGLVersion(3, 3), &oglLoader.callbacks);
    }

    window = creator.createWindow();
    if (window.isNull) return;
    window.title = "Title!";

    Feature_Window_Menu theMenu = window.menu;
    if (theMenu !is null) {
        Window_MenuItem item = theMenu.addItem();
        item.text = "Hi!";
        item.callback = (Window_MenuItem mi) { writeln("Menu Item Click! ", mi.text); };

        Window_MenuItem sub = theMenu.addItem();
        sub.text = "sub";
        Window_MenuItem subItem = sub.addItem();
        subItem.text = "oh yeah!";
        subItem.callback = (Window_MenuItem mi) { writeln("Boo from: ", mi.text); };
    }

    window.events.onForcedDraw = &onForcedDraw;

    window.windowEvents.onMove = (int x, int y) {
        writeln("onMove: x: ", x, " y: ", y);
        stdout.flush;
    };

    window.windowEvents.onRequestClose = () {
        writeln("onRequestClose");
        stdout.flush;
        return true;
    };

    window.events.onCursorMove = (int x, int y) {
        writeln("onCursorMove: x: ", x, " y: ", y);
        stdout.flush;
    };
	
    window.events.onCursorAction = (CursorEventAction action) {
        writeln("onCursorAction: ", action);
        stdout.flush;
    };
	
    window.events.onKeyEntry = (dchar key, SpecialKey specialKey, ushort modifiers) {
        writeln("onKeyEntry: key: ", key, " specialKey: ", specialKey, " modifiers: ", modifiers);
        stdout.flush;

        static if (Enable_Force_Kill_Window) {
            if (specialKey == SpecialKey.Escape) {
                Instance.current.eventLoop.stopAllThreads;
            }
        } else if (specialKey == SpecialKey.Escape)
            window.close();

        if (key == '1')
            window.lockCursorToWindow;
        else if (key == '2')
            window.unlockCursorFromWindow;

        foreach(e; __traits(allMembers, KeyModifiers)) {
            if (modifiers.isBitwiseMask(__traits(getMember, KeyModifiers, e)))
                writeln("\t ", e.stringof);
        }
    };

    window.windowEvents.onKeyPress = (dchar key, SpecialKey specialKey, ushort modifiers) {
        writeln("onKeyPress: key: ", key, " specialKey: ", specialKey, " modifiers: ", modifiers);
        stdout.flush;

        static if (Enable_Force_Kill_Window) {
            if (specialKey == SpecialKey.Escape) {
                Instance.current.eventLoop.stopAllThreads;
            }
        } else if (specialKey == SpecialKey.Escape)
            window.close();

        if (key == '1')
            window.lockCursorToWindow;
        else if (key == '2')
            window.unlockCursorFromWindow;
    	
        foreach(e; __traits(allMembers, KeyModifiers)) {
            if (modifiers.isBitwiseMask(__traits(getMember, KeyModifiers, e)))
                writeln("\t ", e.stringof);
        }
    };
	
    window.windowEvents.onKeyRelease = (dchar key, SpecialKey specialKey, ushort modifiers) {
        writeln("onKeyRelease: key: ", key, " specialKey: ", specialKey, " modifiers: ", modifiers);
        stdout.flush;
    	
        foreach(e; __traits(allMembers, KeyModifiers)) {
            if (modifiers.isBitwiseMask(__traits(getMember, KeyModifiers, e)))
                writeln("\t ", e.stringof);
        }
    };

    window.events.onScroll = (int amount) {
        writeln("onScroll: ", amount);
        stdout.flush;
    };
	
    window.events.onClose = () {
        writeln("onClose");
        stdout.flush;

        static if (Enable_Kill_Window) {
            Instance.current.eventLoop.stopAllThreads;
        }
    };

    window.events.onSizeChange = (uint width, uint height) {
        writeln("onSizeChange: ", width, "x", height);
    };

    window.events.onFileDragStart = () {
        writeln("onFileDragStart");
        stdout.flush;
    };

    window.events.onFileDragStopped = () {
        writeln("onFileDragStopped");
        stdout.flush;
    };

    window.events.onFileDragging = (int x, int y) {
        writeln("onFileDragging ", x, "x", y);
        stdout.flush;
        return x < (window.size.x / 2);
    };

    window.events.onFileDrop = (scope filename, int x, int y) {
        writeln("onFileDrop ", filename, " ", x, "x", y);
        stdout.flush;
    };

    window.events.onVisible = () {
        writeln("onVisible");
        stdout.flush;
    };

    window.events.onInvisible = () {
        writeln("onInvisible");
        stdout.flush;
    };
	
    window.show();

    windowForceDrawTimer = Instance.current.misc.createTimer(dur!"msecs"(32), true);
    windowForceDrawTimer.onEvent = (scope timer) {
        writeln("window force draw timer ticked");

        if (window.renderable)
            onForcedDraw();
    };
    windowForceDrawTimer.onStopped = (scope timer) {
        writeln("window force draw timer stopped");
    };
}

/*
 * The below code is rather complex, far more than required.
 * In real code, you would save the context then for each call:
 *  1. activate
 *  2. readyToBeUsed
 *  3. deactivate
 * 
 * Until you know which kind of context you have (including version)
 *  which has been setup for your use, you must assume none and wait.
 */
void onForcedDraw() {
    import std.stdio : writeln, stdout;
    import devisualization.image.manipulation.base : fillOn;
    import std.experimental.color : RGBA8;

    writeln("onForcedDraw");stdout.flush;
    if (window.context is null || !window.renderable) return;

    window.context.activate;
    if (!window.context.readyToBeUsed) {
        return;
    }

    if (window.context.capableOfVRAM) {
        auto buffer = window.context.vramAlphaBuffer;
        buffer.fillOn(RGBA8(255, 0, 0, 255));
    } else if (window.context.capableOfOpenGL) {
        static if (Enable_Window_GL) {
            int glMajorVersion, glMinorVersion;
            gl.glGetIntegerv(GL_MAJOR_VERSION, &glMajorVersion);
            gl.glGetIntegerv(GL_MINOR_VERSION, &glMinorVersion);

            // OpenGL < 3 don't support the above version, so let's do a more expensive but compat way
            if (glMajorVersion == 0) {
                import std.format : formattedRead;
                import core.stdc.string : strlen;

                char* glText = cast(char*)gl.glGetString(GL_VERSION);
                glText[0 .. strlen(glText)].formattedRead!"%d.%d"(glMajorVersion, glMinorVersion);
            }

            if ((glMajorVersion == 3 && glMinorVersion >= 3) || glMajorVersion > 3) {
                if (!openglContextCreated) {
                    gl.glGenVertexArrays(1, &vertexArrayGL);
                    gl.glBindVertexArray(vertexArrayGL);

                    gl.glGenBuffers(1, &vertexbufferGL);
                    gl.glBindBuffer(GL_ARRAY_BUFFER, vertexbufferGL);
                    gl.glBufferData(GL_ARRAY_BUFFER, opengl_example_vertex_bufferdata.length*float.sizeof, opengl_example_vertex_bufferdata.ptr, GL_STATIC_DRAW);

                    openglContextCreated = true;
                } else if (!openglObjectsCreated) {
                    char* source = cast(char*)VertexShaderGL_Source.ptr;

                    vertexShaderGL = gl.glCreateShader(GL_VERTEX_SHADER);
                    gl.glShaderSource(vertexShaderGL, 1, &source, null);
                    gl.glCompileShader(vertexShaderGL);

                    gl.glGetShaderiv(vertexShaderGL, GL_COMPILE_STATUS, &resultGL);
                    gl.glGetShaderiv(vertexShaderGL, GL_INFO_LOG_LENGTH, &infoLogLengthGL);

                    if (resultGL == GL_FALSE) {
                        char[] log;
                        log.length = infoLogLengthGL+1;
                        gl.glGetShaderInfoLog(vertexShaderGL, infoLogLengthGL, null, log.ptr);
                        writeln("onForcedDraw OGL vertex fail: ", log[0 .. $-1]);
                        return;
                    }

                    source = cast(char*)FragmentShaderGL_Source.ptr;

                    fragmentShaderGL = gl.glCreateShader(GL_FRAGMENT_SHADER);
                    gl.glShaderSource(fragmentShaderGL, 1, &source, null);
                    gl.glCompileShader(fragmentShaderGL);

                    gl.glGetShaderiv(fragmentShaderGL, GL_COMPILE_STATUS, &resultGL);
                    gl.glGetShaderiv(fragmentShaderGL, GL_INFO_LOG_LENGTH, &infoLogLengthGL);

                    if (resultGL == GL_FALSE) {
                        char[] log;
                        log.length = infoLogLengthGL+1;
                        gl.glGetShaderInfoLog(fragmentShaderGL, infoLogLengthGL, null, log.ptr);
                        writeln("onForcedDraw OGL fragment fail: ", log[0 .. $-1]);
                        return;
                    }

                    programGL = gl.glCreateProgram();
                    gl.glAttachShader(programGL, vertexShaderGL);
                    gl.glAttachShader(programGL, fragmentShaderGL);
                    gl.glLinkProgram(programGL);

                    gl.glGetProgramiv(programGL, GL_LINK_STATUS, &resultGL);
                    gl.glGetProgramiv(programGL, GL_INFO_LOG_LENGTH, &infoLogLengthGL);
                    if (resultGL == GL_FALSE) {
                        char[] log;
                        log.length = infoLogLengthGL+1;
                        gl.glGetProgramInfoLog(programGL, infoLogLengthGL, null, log.ptr);
                        writeln("onForcedDraw OGL link fail: ", log[0 .. $-1]);
                        return;
                    }

                    openglObjectsCreated = true;
                } else {
                    gl.glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
                    gl.glUseProgram(programGL);
                    gl.glBindVertexArray(vertexArrayGL);

                    gl.glEnableVertexAttribArray(0);
                    gl.glBindBuffer(GL_ARRAY_BUFFER, vertexbufferGL);
                    gl.glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null);
                    gl.glDrawArrays(GL_TRIANGLES, 0, 3);
                    gl.glDisableVertexAttribArray(0);

                    /+
                    gl.glDetachShader(programGL, vertexShaderGL);
                    gl.glDetachShader(programGL, fragmentShaderGL);
                    gl.glDeleteProgram(programGL);
                    gl.glDeleteShader(vertexShaderGL);
                    gl.glDeleteShader(fragmentShaderGL);+/
                }
            } else {
                auto wsize = window.size;
                gl.glViewport(0, 0, wsize.x, wsize.y);
                gl.glClearColor(0, 0, 0, 1);
                gl.glClear(GL_COLOR_BUFFER_BIT);

                gl.glBegin(GL_QUADS);
                gl.glColor4f(1, 0, 0, 1);
                gl.glVertex2f(-0.5f, -0.5f);
                gl.glVertex2f(0.5f, -0.5f);
                gl.glVertex2f(0.5f, 0.5f);
                gl.glVertex2f(-0.5f, 0.5f);
                gl.glEnd();
            }
        }
    }

    window.context.deactivate;
}

// | /\ windowing
