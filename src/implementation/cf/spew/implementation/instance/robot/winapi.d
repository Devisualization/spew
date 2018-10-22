module cf.spew.implementation.instance.robot.winapi;
version(Windows):
import cf.spew.implementation.windowing.window.winapi;
import cf.spew.events.windowing : KeyModifiers, SpecialKey, CursorEventAction;
import cf.spew.instance : Management_Robot;
import cf.spew.ui.window.defs : IWindow;
import cf.spew.ui.rendering : vec2;
import stdx.allocator : IAllocator, theAllocator, make, makeArray, dispose;
import devisualization.util.core.memory.managed;
import core.thread : Thread;
import core.time : seconds, msecs;
import core.sys.windows.windows : INPUT, VK_LMENU, VK_RMENU, VK_LCONTROL, VK_RCONTROL, VK_LSHIFT, VK_RSHIFT, VK_CAPITAL,
    VK_NUMLOCK, VK_LWIN, VK_RWIN, POINT, GetCursorPos, SetCursorPos, HWND, GetForegroundWindow, SetForegroundWindow,
    FindWindowW, INPUT_KEYBOARD, INPUT_MOUSE, WORD, KEYEVENTF_KEYUP, KEYEVENTF_UNICODE, VK_NUMPAD0,
    VK_OEM_1, VK_OEM_2, VK_OEM_3, VK_OEM_4, VK_OEM_5, VK_OEM_6, VK_OEM_7, VK_OEM_MINUS, VK_OEM_COMMA, VK_OEM_PERIOD,
    VK_DECIMAL, VK_SPACE, VK_OEM_PLUS, VK_ADD, VK_SUBTRACT, VK_MULTIPLY, VK_DIVIDE, SendInput, VK_F1, VK_ESCAPE,
    VK_RETURN, VK_BACK, VK_TAB, VK_PRIOR, VK_NEXT, VK_END, VK_HOME, VK_INSERT, VK_DELETE, VK_PAUSE, VK_LEFT, VK_RIGHT,
    VK_UP, VK_DOWN, VK_SCROLL, RECT, MapWindowPoints, MOUSEEVENTF_WHEEL, MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP,
    MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP, MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP, HWND_DESKTOP,
    HIWORD, GetKeyState;

final class RobotInstance_WinAPI : Management_Robot {
    @property {
        vec2!int mouseLocation() shared {
            POINT point;
            assert(GetCursorPos(&point));
            return vec2!int(point.x, point.y);
        }
        
        managed!IWindow focusWindow(IAllocator alloc = theAllocator()) shared {
            HWND active = GetForegroundWindow();
            
            if (active is null)
                return managed!IWindow.init;
            else
                return managed!IWindow(alloc.make!WindowImpl_WinAPI(active, null, alloc),
                    managers(ReferenceCountedManager()), alloc);
        }
        
        void focusWindow(managed!IWindow window) shared {
            if (window.isNull) return;
            SetForegroundWindow(cast(HWND)window.__handle);
        }
    }

    managed!IWindow findWindow(string title, IAllocator alloc = theAllocator()) shared {
        import std.utf : codeLength, byWchar;
        
        wchar[] title2 = alloc.makeArray!wchar(codeLength!wchar(title) + 1);
        title2[$-1] = 0;
        
        size_t i;
        foreach(c; title.byWchar) {
            title2[i] = c;
            i++;
        }
        
        //
        
        HWND handle = FindWindowW(null, title2.ptr);
        alloc.dispose(title2);
        
        if (handle is null)
            return managed!IWindow.init;
        else {
            return managed!IWindow(alloc.make!WindowImpl_WinAPI(handle, null, alloc),
                managers(ReferenceCountedManager()), alloc);
        }
    }

    void sendKey(dchar key, ushort modifiersToDown, managed!IWindow window = managed!IWindow.init) shared {
        import std.utf : encode;

        uint count;
        INPUT[22] inputs;
        ushort modifiersToUp, currentState;
        
        foreach(i; 0 .. 22) {
            inputs[i].type = INPUT_KEYBOARD;
            inputs[i].ki.wScan = 0;
            inputs[i].ki.dwFlags = 0;
            inputs[i].ki.time = 0;
            inputs[i].ki.dwExtraInfo = 0;
        }

        getKeyModifiers(key, modifiersToDown, modifiersToUp, currentState);
        count += addKeyModifiersStart(inputs[count .. $], modifiersToDown, modifiersToUp, currentState);

        //

        switch(key) {
            case '0': .. case '9':
                if ((modifiersToDown & KeyModifiers.Numlock) == KeyModifiers.Numlock)
                    inputs[count].ki.wVk = cast(WORD)((cast(uint)key - cast(uint)'0') + VK_NUMPAD0);
                else
                    inputs[count].ki.wVk = cast(WORD)key;
                
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;

                count += 2;
                break;

            case 'a': .. case 'z':
                key = cast(dchar)((cast(uint)key) - Atoa);
                goto case 'A';
            case 'A': .. case 'Z':
                inputs[count].ki.wVk = cast(ushort)key;
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;

            case ':':
            case ';':
                inputs[count].ki.wVk = VK_OEM_1;
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;

            case '~':
            case '`':
                inputs[count].ki.wVk = VK_OEM_3;
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;

            case '{':
            case '[':
                inputs[count].ki.wVk = VK_OEM_4;
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;

            case '|':
            case '\\':
                inputs[count].ki.wVk = VK_OEM_5;
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;

            case '}':
            case ']':
                inputs[count].ki.wVk = VK_OEM_6;
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;

            case '"':
            case '\'':
                inputs[count].ki.wVk = VK_OEM_7;
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;
                
            case '_':
                inputs[count].ki.wVk = VK_OEM_MINUS;
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;
                
            case '<':
            case ',':
                inputs[count].ki.wVk = VK_OEM_COMMA;
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;
                
            case '>':
                inputs[count].ki.wVk = VK_OEM_PERIOD;
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;
                
            case '.':
                if ((modifiersToDown & KeyModifiers.Numlock) == KeyModifiers.Numlock) {
                    inputs[count].ki.wVk = VK_DECIMAL;
                } else {
                    inputs[count].ki.wVk = VK_OEM_PERIOD;
                }
                
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;
                
            case ' ':
                inputs[count].ki.wVk = VK_SPACE;
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;
                
            case '=':
                inputs[count].ki.wVk = VK_OEM_PLUS;
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;
                
            case '+':
                if ((modifiersToDown & KeyModifiers.Numlock) == KeyModifiers.Numlock) {
                    inputs[count].ki.wVk = VK_ADD;
                } else {
                    inputs[count].ki.wVk = VK_OEM_PLUS;
                }
                
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;
                
            case '-':
                if ((modifiersToDown & KeyModifiers.Numlock) == KeyModifiers.Numlock) {
                    inputs[count].ki.wVk = VK_SUBTRACT;
                } else
                    inputs[count].ki.wVk = VK_OEM_MINUS;
                
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;
                
            case '*':
                if ((modifiersToDown & KeyModifiers.Numlock) == KeyModifiers.Numlock) {
                    inputs[count].ki.wVk = VK_MULTIPLY;
                    inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                    inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                    count += 2;
                } else {
                    inputs[count].ki.wScan = cast(WORD)'*';
                    inputs[count].ki.dwFlags = KEYEVENTF_UNICODE;
                    count++;
                }
                break;

            case '?':
                inputs[count].ki.wVk = VK_OEM_2;
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;

            case '/':
                if ((modifiersToDown & KeyModifiers.Numlock) == KeyModifiers.Numlock) {
                    inputs[count].ki.wVk = VK_DIVIDE;
                } else
                    inputs[count].ki.wVk = VK_OEM_2;
                
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;

            default:
                wchar[2] temp;
                size_t count2 = temp.encode(key);
                
                if (count2 > 0) {
                    inputs[count].ki.wScan = cast(WORD)temp[0];
                    inputs[count].ki.dwFlags = KEYEVENTF_UNICODE;
                    count++;
                }
                
                if (count2 == 2) {
                    inputs[count].ki.wScan = cast(WORD)temp[1];
                    inputs[count].ki.dwFlags = KEYEVENTF_UNICODE;
                    count++;
                }
                break;
        }

        //

        count += addKeyModifiersEnd(inputs[count .. $], modifiersToDown, modifiersToUp, currentState);

        if (window.isNull) {
            SendInput(count, inputs.ptr, INPUT.sizeof);
        } else {
            HWND previous = GetForegroundWindow();

            if (previous !is cast(HWND)window.__handle) {
                SetForegroundWindow(cast(HWND)window.__handle);
                SendInput(count, inputs.ptr, INPUT.sizeof);

                Thread.sleep(750.msecs);
                SetForegroundWindow(previous);
            } else
                SendInput(count, inputs.ptr, INPUT.sizeof);
        }
    }

    void sendKey(SpecialKey key, managed!IWindow window = managed!IWindow.init) shared {
        uint count;
        INPUT[2] inputs;
        
        foreach(i; 0 .. 2) {
            inputs[i].type = INPUT_KEYBOARD;
            inputs[i].ki.wScan = 0;
            inputs[i].ki.dwFlags = 0;
            inputs[i].ki.time = 0;
            inputs[i].ki.dwExtraInfo = 0;
        }
        
        switch(key) {
            case SpecialKey.F1: .. case SpecialKey.F24:
                inputs[count].ki.wVk = cast(ushort)(VK_F1 + (key - SpecialKey.F1));
                break;
                
            case SpecialKey.Escape:
                inputs[count].ki.wVk = VK_ESCAPE;
                break;
                
            case SpecialKey.Enter:
                inputs[count].ki.wVk = VK_RETURN;
                break;
                
            case SpecialKey.Backspace:
                inputs[count].ki.wVk = VK_BACK;
                break;
                
            case SpecialKey.Tab:
                inputs[count].ki.wVk = VK_TAB;
                break;
                
            case SpecialKey.PageUp:
                inputs[count].ki.wVk = VK_PRIOR;
                break;
                
            case SpecialKey.PageDown:
                inputs[count].ki.wVk = VK_NEXT;
                break;
                
            case SpecialKey.End:
                inputs[count].ki.wVk = VK_END;
                break;
                
            case SpecialKey.Home:
                inputs[count].ki.wVk = VK_HOME;
                break;
                
            case SpecialKey.Insert:
                inputs[count].ki.wVk = VK_INSERT;
                break;
                
            case SpecialKey.Delete:
                inputs[count].ki.wVk = VK_DELETE;
                break;
                
            case SpecialKey.Pause:
                inputs[count].ki.wVk = VK_PAUSE;
                break;
                
            case SpecialKey.LeftArrow:
                inputs[count].ki.wVk = VK_LEFT;
                break;
                
            case SpecialKey.RightArrow:
                inputs[count].ki.wVk = VK_RIGHT;
                break;
                
            case SpecialKey.UpArrow:
                inputs[count].ki.wVk = VK_UP;
                break;
                
            case SpecialKey.DownArrow:
                inputs[count].ki.wVk = VK_DOWN;
                break;
                
            case SpecialKey.ScrollLock:
                inputs[count].ki.wVk = VK_SCROLL;
                break;
                
            default:
                return;
        }
        
        inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
        inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
        count += 2;
    
        if (window.isNull) {
            SendInput(count, inputs.ptr, INPUT.sizeof);
        } else {
            HWND previous = GetForegroundWindow();
            
            if (previous !is cast(HWND)window.__handle) {
                SetForegroundWindow(cast(HWND)window.__handle);
                SendInput(count, inputs.ptr, INPUT.sizeof);
                
                Thread.sleep(750.msecs);
                SetForegroundWindow(previous);
            } else
                SendInput(count, inputs.ptr, INPUT.sizeof);
        }
    }

    void sendScroll(int x, int y, int amount, managed!IWindow window = managed!IWindow.init) shared {
        if (!window.isNull) {
            RECT rect;
            rect.top = x;
            rect.bottom = y;
            
            MapWindowPoints(cast(HWND)window.__handle, HWND_DESKTOP, cast(POINT*)&rect, 2);
            
            x = rect.left;
            y = rect.top;
        }
        
        SetCursorPos(x, y);
        
        INPUT input = INPUT(INPUT_MOUSE);
        input.mi.mouseData = amount * 120;
        input.mi.dwFlags = MOUSEEVENTF_WHEEL;
        
        if (window.isNull) {
            SendInput(1, &input, INPUT.sizeof);
        } else {
            HWND previous = GetForegroundWindow();
            
            if (previous !is cast(HWND)window.__handle) {
                SetForegroundWindow(cast(HWND)window.__handle);
                SendInput(1, &input, INPUT.sizeof);
                
                Thread.sleep(750.msecs);
                SetForegroundWindow(previous);
            } else
                SendInput(1, &input, INPUT.sizeof);
        }
    }

    void sendMouse(int x, int y, bool isDown, CursorEventAction action, managed!IWindow window = managed!IWindow.init) shared {
        if (!window.isNull) {
            RECT rect;
            rect.top = x;
            rect.bottom = y;
            
            MapWindowPoints(cast(HWND)window.__handle, HWND_DESKTOP, cast(POINT*)&rect, 2);
            
            x = rect.left;
            y = rect.top;
        }
        
        SetCursorPos(x, y);
        
        INPUT input = INPUT(INPUT_MOUSE);

        final switch(action) {
            case CursorEventAction.Select:
                if (isDown)
                    input.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
                else
                    input.mi.dwFlags = MOUSEEVENTF_LEFTUP;
                break;
                
            case CursorEventAction.Alter:
                if (isDown)
                    input.mi.dwFlags = MOUSEEVENTF_RIGHTDOWN;
                else
                    input.mi.dwFlags = MOUSEEVENTF_RIGHTUP;
                break;
                
            case CursorEventAction.ViewChange:
                if (isDown)
                    input.mi.dwFlags = MOUSEEVENTF_MIDDLEDOWN;
                else
                    input.mi.dwFlags = MOUSEEVENTF_MIDDLEUP;
                break;
        }
        
        if (window.isNull) {
            SendInput(1, &input, INPUT.sizeof);
        } else {
            HWND previous = GetForegroundWindow();
            
            if (previous !is cast(HWND)window.__handle) {
                SetForegroundWindow(cast(HWND)window.__handle);
                SendInput(1, &input, INPUT.sizeof);
                
                Thread.sleep(750.msecs);
                SetForegroundWindow(previous);
            } else
                SendInput(1, &input, INPUT.sizeof);
        }
    }

    void sendMouseMove(int x, int y, managed!IWindow window = managed!IWindow.init) shared {
        if (!window.isNull) {
            RECT rect;
            rect.top = x;
            rect.bottom = y;
            
            MapWindowPoints(cast(HWND)window.__handle, HWND_DESKTOP, cast(POINT*)&rect, 2);
            
            x = rect.left;
            y = rect.top;
        }
        
        SetCursorPos(x, y);
    }

    void sendMouseClick(int x, int y, CursorEventAction action, managed!IWindow window = managed!IWindow.init) shared {
        if (!window.isNull) {
            RECT rect;
            rect.top = x;
            rect.bottom = y;
            
            MapWindowPoints(cast(HWND)window.__handle, HWND_DESKTOP, cast(POINT*)&rect, 2);
            
            x = rect.left;
            y = rect.top;
        }
        
        SetCursorPos(x, y);
        
        INPUT input = INPUT(INPUT_MOUSE);
        
        final switch(action) {
            case CursorEventAction.Select:
                input.mi.dwFlags = MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP;
                break;
                
            case CursorEventAction.Alter:
                input.mi.dwFlags = MOUSEEVENTF_RIGHTDOWN | MOUSEEVENTF_RIGHTUP;
                break;
                
            case CursorEventAction.ViewChange:
                input.mi.dwFlags = MOUSEEVENTF_MIDDLEDOWN | MOUSEEVENTF_MIDDLEUP;
                break;
        }
        
        if (window.isNull) {
            SendInput(1, &input, INPUT.sizeof);
        } else {
            HWND previous = GetForegroundWindow();
            
            if (previous !is cast(HWND)window.__handle) {
                SetForegroundWindow(cast(HWND)window.__handle);
                SendInput(1, &input, INPUT.sizeof);
                
                Thread.sleep(750.msecs);
                SetForegroundWindow(previous);
            } else
                SendInput(1, &input, INPUT.sizeof);
        }
    }
}

private:

enum Atoa = 'a' - 'A';
enum AllKeyModifiers = [KeyModifiers.LAlt, KeyModifiers.RAlt, KeyModifiers.LControl, KeyModifiers.RControl,
    KeyModifiers.LShift, KeyModifiers.RShift, KeyModifiers.Capslock, KeyModifiers.Numlock,
    KeyModifiers.LSuper, KeyModifiers.RSuper];
enum AllVirtualKeyModifiers = [VK_LMENU, VK_RMENU, VK_LCONTROL, VK_RCONTROL, VK_LSHIFT,
    VK_RSHIFT, VK_CAPITAL, VK_NUMLOCK, VK_LWIN, VK_RWIN];

void getKeyModifiers(dchar key, ref ushort modifiersToDown, ref ushort modifiersToUp, out ushort currentState) {
    // modify what to set down and set what needs to go up

    switch(key) {
        case '{':
        case '}':
        case '?':
        case '~':
        case '*':
        case'|':
        case '>':
        case '<':
        case '_':
        case '"':
        case ':':
        case 'A': .. case 'Z':
            modifiersToDown |= KeyModifiers.LShift | KeyModifiers.RShift;
            break;

        case'[':
        case ']':
        case '`':
        case '=':
        case '\\':
        case '.':
        case '\'':
        case ',':
        case ';':
        case '0': .. case '9':
        case 'a': .. case 'z':
            modifiersToDown &= ~(KeyModifiers.LShift | KeyModifiers.RShift);
            modifiersToUp |= KeyModifiers.LShift | KeyModifiers.RShift;
            break;
            
        default:
            break;
    }

    // now grab the current state

    foreach(i, KM; AllKeyModifiers) {
        if (HIWORD(GetKeyState(AllVirtualKeyModifiers[i])) != 0)
            currentState |= KM;
    }
}

uint addKeyModifiersStart(INPUT[] inputs, ushort modifiersToDown, ushort modifiersToUp, ushort currentState) {
    uint count;

    // we should only press a key down if it already isn't pressed
    // nor should we unpress a key if it is already not pressed

    foreach(i, KM; AllKeyModifiers) {
        if ((modifiersToDown & KM) == KM && (currentState & KM) != KM)
            inputs[count++].ki.wVk = cast(ushort)AllVirtualKeyModifiers[i];
        else if ((modifiersToUp & KM) == KM && (currentState & KM) == KM) {
            inputs[count].ki.wVk = cast(ushort)AllVirtualKeyModifiers[i];
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }
    }
    
    return count;
}

uint addKeyModifiersEnd(INPUT[] inputs, ushort modifiersToDown, ushort modifiersToUp, ushort currentState) {
    uint count;

    // we should only unpress a key if we pressed it
    // nor should we press a key if it is already not pressed

    foreach(i, KM; AllKeyModifiers) {
        if ((modifiersToUp & KM) == KM && (currentState & KM) == KM)
            inputs[count++].ki.wVk = cast(ushort)AllVirtualKeyModifiers[i];
        else if ((modifiersToDown & KM) == KM && (currentState & KM) != KM) {
            inputs[count].ki.wVk = cast(ushort)AllVirtualKeyModifiers[i];
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }
    }
    
    return count;
}