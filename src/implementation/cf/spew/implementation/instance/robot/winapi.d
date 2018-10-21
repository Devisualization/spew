module cf.spew.implementation.instance.robot.winapi;
version(Windows):
import cf.spew.instance : Management_Robot;
import cf.spew.events.windowing : KeyModifiers, SpecialKey, CursorEventAction;
import cf.spew.ui.rendering : vec2;
import cf.spew.ui.window.defs : IWindow;
import stdx.allocator : IAllocator, theAllocator, make, makeArray, dispose;
import devisualization.util.core.memory.managed;
import core.sys.windows.windows : SetActiveWindow, GetActiveWindow, HWND, INPUT, SendInput, INPUT_KEYBOARD,
    VK_DIVIDE, VK_OEM_2, VK_MULTIPLY, KEYEVENTF_KEYUP, VK_LMENU, VK_RMENU, VK_LCONTROL, VK_RCONTROL,
    VK_LSHIFT, VK_RSHIFT, VK_CAPITAL, VK_NUMLOCK, VK_LWIN, VK_RWIN, HIWORD, GetKeyState,
    VK_DECIMAL, VK_SPACE, VK_OEM_PLUS, VK_ADD, VK_SUBTRACT, VK_OEM_MINUS, WORD, KEYEVENTF_UNICODE,
    VK_OEM_1, VK_OEM_COMMA, VK_OEM_PERIOD, VK_OEM_7, VK_OEM_5, VK_NUMPAD0, VK_F1, VK_ESCAPE, VK_RETURN,
    VK_BACK, VK_TAB, VK_PRIOR, VK_NEXT, VK_END, VK_HOME, VK_INSERT, VK_DELETE, VK_PAUSE, VK_LEFT, VK_RIGHT,
    VK_UP, VK_DOWN, VK_SCROLL, INPUT_MOUSE, MOUSEEVENTF_MOVE, MOUSEEVENTF_ABSOLUTE, MOUSEEVENTF_WHEEL,
    MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP, MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP, GetWindowLongA,
    MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP, RECT, AdjustWindowRectEx, GetWindowRect, GetMenu,
    GWL_STYLE, GWL_EXSTYLE, GetCursorPos, POINT, FindWindowW;

final class RobotInstance_WinAPI : Management_Robot {
    import cf.spew.implementation.windowing.window.winapi;

    @property {
        vec2!int mouseLocation() shared {
            POINT point;
            assert(GetCursorPos(&point));
            return vec2!int(point.x, point.y);
        }

        managed!IWindow focusWindow(IAllocator alloc = theAllocator()) shared {
            HWND active = GetActiveWindow();
            
            if (active is null)
                return managed!IWindow.init;
            else
                return managed!IWindow(alloc.make!WindowImpl_WinAPI(active, null, alloc),
                    managers(ReferenceCountedManager()), alloc);
        }
        
        void focusWindow(managed!IWindow window) shared {
            if (window.isNull) return;
            SetActiveWindow(cast(HWND)window.__handle);
        }
    }

    managed!IWindow findWindow(string title, IAllocator alloc = theAllocator()) {
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

    void sendKey(dchar key, ushort modifiers, managed!IWindow window = managed!IWindow.init) shared {
        enum Atoa = 'a' - 'A';

        uint count;
        INPUT[22] inputs;
        ushort inverseModifiers;

        foreach(i; 0 .. 22) {
            inputs[i] = INPUT(INPUT_KEYBOARD);
        }

        getKeyModifiers(key, modifiers, inverseModifiers);
        count += setKeyModifiersStart(inputs[], modifiers, inverseModifiers);
        
        switch(key) {
           case '0': .. case '9':
                if ((modifiers & KeyModifiers.Numlock) == KeyModifiers.Numlock)
                    inputs[count].ki.wVk = cast(WORD)((cast(uint)key - cast(uint)'0') + VK_NUMPAD0);
                else
                    inputs[count].ki.wVk = cast(WORD)key;

                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;

            case 'A': .. case 'Z':
                key = cast(dchar)((cast(uint)key) - Atoa);
                goto case 'a';
            case 'a': .. case 'z':
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

            case '"':
            case '\'':
                inputs[count].ki.wVk = VK_OEM_7;
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

            case '.':
                if ((modifiers & KeyModifiers.Numlock) == KeyModifiers.Numlock) {
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
                if ((modifiers & KeyModifiers.Numlock) == KeyModifiers.Numlock) {
                    inputs[count].ki.wVk = VK_ADD;
                } else {
                    inputs[count].ki.wVk = VK_OEM_PLUS;
                }

                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;
                
            case '-':
                if ((modifiers & KeyModifiers.Numlock) == KeyModifiers.Numlock) {
                    inputs[count].ki.wVk = VK_SUBTRACT;
                } else
                    inputs[count].ki.wVk = VK_OEM_MINUS;
                
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;
                
            case '*':
                if ((modifiers & KeyModifiers.Numlock) == KeyModifiers.Numlock) {
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
                
            case '/':
                if ((modifiers & KeyModifiers.Numlock) == KeyModifiers.Numlock) {
                    inputs[count].ki.wVk = VK_DIVIDE;
                } else
                    inputs[count].ki.wVk = VK_OEM_2;
                
                inputs[count + 1].ki.wVk = inputs[count].ki.wVk;
                inputs[count + 1].ki.dwFlags = KEYEVENTF_KEYUP;
                count += 2;
                break;
                
            default:
                import std.utf : encode;
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
        
        count += setKeyModifiersEnd(inputs[count .. $], modifiers, inverseModifiers);
        
        if (window.isNull) {
            SendInput(count, inputs.ptr, INPUT.sizeof);
        } else {
            HWND previous = SetActiveWindow(cast(HWND)window.__handle);
            SendInput(count, inputs.ptr, INPUT.sizeof);
            
            if (previous !is null)
                SetActiveWindow(previous);
        }
    }

    void sendKey(SpecialKey key, managed!IWindow window = managed!IWindow.init) shared {
        uint count;
        INPUT[2] inputs;
        
        foreach(i; 0 .. 2) {
            inputs[i] = INPUT(INPUT_KEYBOARD);
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
            HWND previous = SetActiveWindow(cast(HWND)window.__handle);
            SendInput(count, inputs.ptr, INPUT.sizeof);
            
            if (previous !is null)
                SetActiveWindow(previous);
        }
    }

    void sendScroll(int x, int y, int amount, managed!IWindow window = managed!IWindow.init) shared {
        INPUT input = INPUT(INPUT_MOUSE);

        if (!window.isNull) {
            adjustCoordinateToWindowContentArea(cast(HWND)window.__handle, x, y);
        }

        input.mi.dx = x;
        input.mi.dy = y;
        input.mi.mouseData = amount * 120;
        input.mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_WHEEL;

        if (window.isNull) {
            SendInput(1, &input, INPUT.sizeof);
        } else {
            HWND previous = SetActiveWindow(cast(HWND)window.__handle);
            SendInput(1, &input, INPUT.sizeof);
            
            if (previous !is null)
                SetActiveWindow(previous);
        }
    }

    void sendMouse(int x, int y, bool isDown, CursorEventAction action, managed!IWindow window = managed!IWindow.init) shared {
        INPUT input = INPUT(INPUT_MOUSE);

        if (!window.isNull) {
            adjustCoordinateToWindowContentArea(cast(HWND)window.__handle, x, y);
        }
        
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
        
        input.mi.dx = x;
        input.mi.dy = y;
        input.mi.dwFlags |= MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE;
        
        if (window.isNull) {
            SendInput(1, &input, INPUT.sizeof);
        } else {
            HWND previous = SetActiveWindow(cast(HWND)window.__handle);
            SendInput(1, &input, INPUT.sizeof);
            
            if (previous !is null)
                SetActiveWindow(previous);
        }
    }

    void sendMouseMove(int x, int y, managed!IWindow window = managed!IWindow.init) shared {
        INPUT input = INPUT(INPUT_MOUSE);
        
        if (!window.isNull) {
            adjustCoordinateToWindowContentArea(cast(HWND)window.__handle, x, y);
        }

        input.mi.dx = x;
        input.mi.dy = y;
        input.mi.dwFlags |= MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE;

        if (window.isNull) {
            SendInput(1, &input, INPUT.sizeof);
        } else {
            HWND previous = SetActiveWindow(cast(HWND)window.__handle);
            SendInput(1, &input, INPUT.sizeof);
            
            if (previous !is null)
                SetActiveWindow(previous);
        }
    }

    void sendMouseClick(int x, int y, CursorEventAction action, managed!IWindow window = managed!IWindow.init) shared {
        uint count;
        INPUT[2] inputs;
        
        foreach(i; 0 .. 2) {
            inputs[i] = INPUT(INPUT_MOUSE);
        }

        if (!window.isNull) {
            adjustCoordinateToWindowContentArea(cast(HWND)window.__handle, x, y);
        }

        final switch(action) {
            case CursorEventAction.Select:
                inputs[count].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
                inputs[count+1].mi.dwFlags = MOUSEEVENTF_LEFTUP;
                break;

            case CursorEventAction.Alter:
                inputs[count].mi.dwFlags = MOUSEEVENTF_RIGHTDOWN;
                inputs[count+1].mi.dwFlags = MOUSEEVENTF_RIGHTUP;
                break;

            case CursorEventAction.ViewChange:
                inputs[count].mi.dwFlags = MOUSEEVENTF_MIDDLEDOWN;
                inputs[count+1].mi.dwFlags = MOUSEEVENTF_MIDDLEUP;
                break;
        }

        inputs[count].mi.dx = x;
        inputs[count].mi.dy = y;
        inputs[count++].mi.dwFlags |= MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE;

        inputs[count].mi.dx = x;
        inputs[count].mi.dy = y;
        inputs[count++].mi.dwFlags |= MOUSEEVENTF_ABSOLUTE;

        if (window.isNull) {
            SendInput(count, inputs.ptr, INPUT.sizeof);
        } else {
            HWND previous = SetActiveWindow(cast(HWND)window.__handle);
            SendInput(count, inputs.ptr, INPUT.sizeof);
            
            if (previous !is null)
                SetActiveWindow(previous);
        }
    }
}


private {
    void adjustCoordinateToWindowContentArea(HWND hwnd, ref int x, ref int y) {
        RECT rect;
        rect.top = x;
        rect.bottom = y;

        // step 1, adjust our offsets so they go /into/ the right place of the content area
        if (AdjustWindowRectEx(&rect, GetWindowLongA(hwnd, GWL_STYLE), GetMenu(hwnd) !is null, GetWindowLongA(hwnd, GWL_EXSTYLE))) {
            x = rect.left;
            y = rect.top;
        }

        // step 2, now add the window coordinates on to make them absolute

        GetWindowRect(hwnd, &rect);
        x += rect.left;
        y += rect.top;
    }

    void getKeyModifiers(dchar key, ref ushort modifiers, ref ushort inverseModifiers) {
        switch(key) {
            case '*':
            case'|':
            case '>':
            case '<':
            case '_':
            case ':':
            case 'A': .. case 'Z':
                modifiers |= KeyModifiers.LShift;
                break;
               
            case '=':
            case '\\':
            case '.':
            case ',':
            case ';':
            case 'a': .. case 'z':
                modifiers &= ~(KeyModifiers.LShift | KeyModifiers.RShift);
                inverseModifiers |= KeyModifiers.LShift;
                inverseModifiers |= KeyModifiers.RShift;
                break;

            default:
                break;
        }
    }

    uint setKeyModifiersStart(INPUT[] inputs, ushort modifiers, ushort inverseModifiers) {
        uint count;

        if ((modifiers & KeyModifiers.LAlt) == KeyModifiers.LAlt)
            inputs[count++].ki.wVk = VK_LMENU;
        else if ((inverseModifiers & KeyModifiers.LAlt) == KeyModifiers.LAlt) {
            inputs[count].ki.wVk = VK_LMENU;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }

        if ((modifiers & KeyModifiers.RAlt) == KeyModifiers.RAlt)
            inputs[count++].ki.wVk = VK_RMENU;
        else if ((inverseModifiers & KeyModifiers.RAlt) == KeyModifiers.RAlt) {
            inputs[count].ki.wVk = VK_RMENU;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }

        if ((modifiers & KeyModifiers.LControl) == KeyModifiers.LControl)
            inputs[count++].ki.wVk = VK_LCONTROL;
        else if ((inverseModifiers & KeyModifiers.LControl) == KeyModifiers.LControl) {
            inputs[count].ki.wVk = VK_LCONTROL;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }

        if ((modifiers & KeyModifiers.RControl) == KeyModifiers.RControl)
            inputs[count++].ki.wVk = VK_RCONTROL;
        else if ((inverseModifiers & KeyModifiers.RControl) == KeyModifiers.RControl) {
            inputs[count].ki.wVk = VK_RCONTROL;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }

        if ((modifiers & KeyModifiers.LShift) == KeyModifiers.LShift)
            inputs[count++].ki.wVk = VK_LSHIFT;
        else if ((inverseModifiers & KeyModifiers.LShift) == KeyModifiers.LShift) {
            inputs[count].ki.wVk = VK_LSHIFT;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }

        if ((modifiers & KeyModifiers.RShift) == KeyModifiers.RShift)
            inputs[count++].ki.wVk = VK_RSHIFT;
        else if ((inverseModifiers & KeyModifiers.RShift) == KeyModifiers.RShift) {
            inputs[count].ki.wVk = VK_RSHIFT;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }

        if ((modifiers & KeyModifiers.Capslock) == KeyModifiers.Capslock)
            inputs[count++].ki.wVk = VK_CAPITAL;
        else if ((inverseModifiers & KeyModifiers.Capslock) == KeyModifiers.Capslock) {
            inputs[count].ki.wVk = VK_CAPITAL;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }

        if ((modifiers & KeyModifiers.Numlock) == KeyModifiers.Numlock)
            inputs[count++].ki.wVk = VK_NUMLOCK;
        else if ((inverseModifiers & KeyModifiers.Numlock) == KeyModifiers.Numlock) {
            inputs[count].ki.wVk = VK_NUMLOCK;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }

        if ((modifiers & KeyModifiers.LSuper) == KeyModifiers.LSuper)
            inputs[count++].ki.wVk = VK_LWIN;
        else if ((inverseModifiers & KeyModifiers.LSuper) == KeyModifiers.LSuper) {
            inputs[count].ki.wVk = VK_LWIN;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }

        if ((modifiers & KeyModifiers.RSuper) == KeyModifiers.RSuper)
            inputs[count++].ki.wVk = VK_RWIN;
        else if ((inverseModifiers & KeyModifiers.RSuper) == KeyModifiers.RSuper) {
            inputs[count].ki.wVk = VK_RWIN;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }

        return count;
    }

    uint setKeyModifiersEnd(INPUT[] inputs, ushort modifiers, ushort inverseModifiers) {
        uint count;
        
        if ((inverseModifiers & KeyModifiers.LAlt) == KeyModifiers.LAlt && HIWORD(GetKeyState(VK_LMENU)) == 0)
            inputs[count++].ki.wVk = VK_LMENU;
        else if ((modifiers & KeyModifiers.LAlt) == KeyModifiers.LAlt) {
            inputs[count].ki.wVk = VK_LMENU;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }
        
        if ((inverseModifiers & KeyModifiers.RAlt) == KeyModifiers.RAlt && HIWORD(GetKeyState(VK_RMENU)) == 0)
            inputs[count++].ki.wVk = VK_RMENU;
        else if ((modifiers & KeyModifiers.RAlt) == KeyModifiers.RAlt && HIWORD(GetKeyState(VK_RMENU)) != 0) {
            inputs[count].ki.wVk = VK_RMENU;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }
        
        if ((inverseModifiers & KeyModifiers.LControl) == KeyModifiers.LControl && HIWORD(GetKeyState(VK_LCONTROL)) == 0)
            inputs[count++].ki.wVk = VK_LCONTROL;
        else if ((modifiers & KeyModifiers.LControl) == KeyModifiers.LControl && HIWORD(GetKeyState(VK_LCONTROL)) != 0) {
            inputs[count].ki.wVk = VK_LCONTROL;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }
        
        if ((inverseModifiers & KeyModifiers.RControl) == KeyModifiers.RControl && HIWORD(GetKeyState(VK_RCONTROL)) == 0)
            inputs[count++].ki.wVk = VK_RCONTROL;
        else if ((modifiers & KeyModifiers.RControl) == KeyModifiers.RControl && HIWORD(GetKeyState(VK_RCONTROL)) != 0) {
            inputs[count].ki.wVk = VK_RCONTROL;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }
        
        if ((inverseModifiers & KeyModifiers.LShift) == KeyModifiers.LShift && HIWORD(GetKeyState(VK_LSHIFT)) == 0)
            inputs[count++].ki.wVk = VK_LSHIFT;
        else if ((modifiers & KeyModifiers.LShift) == KeyModifiers.LShift && HIWORD(GetKeyState(VK_LSHIFT)) != 0) {
            inputs[count].ki.wVk = VK_LSHIFT;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }
        
        if ((inverseModifiers & KeyModifiers.RShift) == KeyModifiers.RShift && HIWORD(GetKeyState(VK_RSHIFT)) == 0)
            inputs[count++].ki.wVk = VK_RSHIFT;
        else if ((modifiers & KeyModifiers.RShift) == KeyModifiers.RShift && HIWORD(GetKeyState(VK_RSHIFT)) != 0) {
            inputs[count].ki.wVk = VK_RSHIFT;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }
        
        if ((inverseModifiers & KeyModifiers.Capslock) == KeyModifiers.Capslock && HIWORD(GetKeyState(VK_CAPITAL)) == 0)
            inputs[count++].ki.wVk = VK_CAPITAL;
        else if ((modifiers & KeyModifiers.Capslock) == KeyModifiers.Capslock && HIWORD(GetKeyState(VK_CAPITAL)) != 0) {
            inputs[count].ki.wVk = VK_CAPITAL;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }
        
        if ((inverseModifiers & KeyModifiers.Numlock) == KeyModifiers.Numlock && HIWORD(GetKeyState(VK_NUMLOCK)) == 0)
            inputs[count++].ki.wVk = VK_NUMLOCK;
        else if ((modifiers & KeyModifiers.Numlock) == KeyModifiers.Numlock && HIWORD(GetKeyState(VK_NUMLOCK)) != 0) {
            inputs[count].ki.wVk = VK_NUMLOCK;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }
        
        if ((inverseModifiers & KeyModifiers.LSuper) == KeyModifiers.LSuper && HIWORD(GetKeyState(VK_LWIN)) == 0)
            inputs[count++].ki.wVk = VK_LWIN;
        else if ((modifiers & KeyModifiers.LSuper) == KeyModifiers.LSuper && HIWORD(GetKeyState(VK_LWIN)) != 0) {
            inputs[count].ki.wVk = VK_LWIN;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }
        
        if ((inverseModifiers & KeyModifiers.RSuper) == KeyModifiers.RSuper && HIWORD(GetKeyState(VK_RWIN)) == 0)
            inputs[count++].ki.wVk = VK_RWIN;
        else if ((modifiers & KeyModifiers.RSuper) == KeyModifiers.RSuper && HIWORD(GetKeyState(VK_RWIN)) != 0) {
            inputs[count].ki.wVk = VK_RWIN;
            inputs[count++].ki.dwFlags = KEYEVENTF_KEYUP;
        }
        
        return count;
    }

}