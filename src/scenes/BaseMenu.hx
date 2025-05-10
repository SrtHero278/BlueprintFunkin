package scenes;

import bindings.Glfw;

class BaseMenu extends blueprint.Scene {
    var cancelInput:Bool = false;
    var subMenu:BaseMenu;

    var acceptKeybind:Int = Glfw.KEY_ENTER;
    var cancelKeybind:Int = Glfw.KEY_ESCAPE;
    var keybinds:Array<Int> = [Glfw.KEY_UP, Glfw.KEY_DOWN];
    var subKeybinds:Array<Int> = [];
    var curItem:Int;
    var curSubItem:Int;

    override function keyDown(keyCode:Int, scanCode:Int, mods:Int) {
        if (subMenu != null) {
            subMenu.keyDown(keyCode, scanCode, mods);
            return;
        } else if (cancelInput)
            return;
        
        if (keyCode == acceptKeybind) {
            accept();
            return;
        } else if (keyCode == cancelKeybind) {
            cancel();
            return;
        }

        var keyIndex = keybinds.indexOf(keyCode);
        var subIndex = subKeybinds.indexOf(keyCode);

        if (keyIndex >= 0) {
            final dir = (-1 + 2 * keyIndex);
            curItem = (curItem + dir + getMaxItems()) % getMaxItems();
            changeItem(dir);
        } else if (subIndex >= 0) {
            final dir = (-1 + 2 * subIndex);
            curSubItem = (curSubItem + dir + getMaxSubItems()) % getMaxSubItems();
            changeSubItem(dir);
        }
    }

    function changeItem(direction:Int) {}
    function changeSubItem(direction:Int) {}
    function accept() {}
    function cancel() {}

    function getMaxItems():Int {
        return 0;
    }
    function getMaxSubItems():Int {
        return 0;
    }
}