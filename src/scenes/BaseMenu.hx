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
            curItem = (curItem + (-1 + 2 * keyIndex) + getMaxItems()) % getMaxItems();
            changeItem();
        } else if (subIndex >= 0) {
            curSubItem = (curSubItem + (-1 + 2 * subIndex) + getMaxSubItems()) % getMaxSubItems();
            changeSubItem();
        }
    }

    function changeItem() {}
    function changeSubItem() {}
    function accept() {}
    function cancel() {}

    function getMaxItems():Int {
        return 0;
    }
    function getMaxSubItems():Int {
        return 0;
    }
}