package;

import flixel.FlxGame;
import flixel.FlxG;
import openfl.display.Sprite;
import openfl.Lib;
import openfl.display.StageScaleMode;
import lime.app.Application;
import states.TitleState;

// Advanced Memory Management
#if cpp
import cpp.NativeGc;
import backend.Native;
#end

// Advanced Scripting & Logging
#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import psychlua.HScript.HScriptInfos;
#end

/**
 * @author Brenninho-Stuff (Advanced Refactor)
 * High-performance entry point for Psych Engine forks.
 */
class Main extends Sprite
{
    // Global Config Object
    public static final config = {
        width: 1280,
        height: 720,
        initialState: TitleState,
        zoom: -1.0, // Auto-scale
        framerate: 144, // High-refresh default
        skipSplash: true,
        startFullscreen: false
    };

    public static var fpsVar:debug.FPSCounter;
    public static var instance:Main;

    public static function main():Void
    {
        // Optimization: Pre-initialize Native GC before Lib.current
        #if cpp
        NativeGc.enable(true);
        NativeGc.run(true); // Initial clean sweep
        #end

        Lib.current.addChild(new Main());
    }

    public function new()
    {
        super();
        instance = this;

        // Stage Ready Check
        if (stage != null) init();
        else addEventListener(openfl.events.Event.ADDED_TO_STAGE, init);
    }

    private function init(?E:openfl.events.Event):Void
    {
        if (hasEventListener(openfl.events.Event.ADDED_TO_STAGE))
            removeEventListener(openfl.events.Event.ADDED_TO_STAGE, init);

        setupApplication();
        setupCrashHandler();
        setupScriptingEngine();
        
        // Start Game
        var game = new FlxGame(
            config.width, 
            config.height, 
            #if COPYSTATE_ALLOWED !states.CopyState.checkExistingFiles() ? states.CopyState : #end config.initialState, 
            config.framerate, 
            config.framerate, 
            config.skipSplash, 
            config.startFullscreen
        );
        
        addChild(game);

        setupPostInitialize();
    }

    private function setupApplication():Void
    {
        #if mobile
        Sys.setCwd(mobile.backend.StorageUtil.getStorageDirectory());
        #end

        #if (cpp && windows)
        backend.Native.fixScaling(); // Fix DPI scaling for 4K monitors
        #end

        // Advanced Lib.current optimization
        Lib.current.stage.align = "tl";
        Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
        
        fpsVar = new debug.FPSCounter(10, 3, 0xFFFFFF);
        addChild(fpsVar);
        
        // Dynamic VSync based on user prefs
        Application.current.window.vsync = backend.ClientPrefs.data.vsync;
    }

    /**
     * Advanced Iris (HScript) Wrapper
     * Redirects internal engine logs to the Debug Overlay and external console.
     */
    private function setupScriptingEngine():Void
    {
        #if HSCRIPT_ALLOWED
        var logWrapper = function(level:crowplexus.iris.Iris.LogLevel, x:Dynamic, ?pos:haxe.PosInfos) {
            var color:Int = switch(level) {
                case WARN: 0xFFFF00;
                case ERROR: 0xFF0000;
                case FATAL: 0x8B0000;
                default: 0xFFFFFF;
            }
            
            Iris.logLevel(level, x, pos);
            if (states.PlayState.instance != null)
                states.PlayState.instance.addTextToDebug('[${level}] $x', color);
            
            #if debug trace('[${level}] $x at ${pos.fileName}:${pos.lineNumber}'); #end
        };

        Iris.warn = logWrapper.bind(WARN);
        Iris.error = logWrapper.bind(ERROR);
        Iris.fatal = logWrapper.bind(FATAL);
        #end
    }

    private function setupCrashHandler():Void
    {
        backend.CrashHandler.init();
        #if (linux && !debug)
        // Auto-enable Gamemode for Linux users (Performance boost)
        #end
    }

    private function setupPostInitialize():Void
    {
        // Advanced Signal Handling for Resizing & Shader Cache Fix
        FlxG.signals.gameResized.add(onResize);
        
        #if html5
        FlxG.autoPause = false;
        #end

        // Prevent heavy stutter on focus lost
        FlxG.game.focusLostFramerate = #if mobile 30 #else 60 #end;
        
        // High-level Garbage Collection Hook
        FlxG.signals.postStateSwitch.add(function() {
            #if cpp 
            NativeGc.run(true); 
            NativeGc.compact(); // Defragment memory after state switch
            #end
        });
    }

    /**
     * Performance-Critical: Clears Bitmap Cache to prevent memory leaks during resize
     */
    private function onResize(w:Int, h:Int):Void
    {
        if (fpsVar != null)
            fpsVar.positionFPS(10, 3, Math.min(w / FlxG.width, h / FlxG.height));

        if (FlxG.cameras != null) {
            for (cam in FlxG.cameras.list) {
                if (cam != null && cam.filters != null)
                    resetSpriteCache(cam.flashSprite);
            }
        }
        if (FlxG.game != null) resetSpriteCache(FlxG.game);
    }

    @:access(openfl.display.DisplayObject)
    private static function resetSpriteCache(sprite:Sprite):Void {
        sprite.__cacheBitmap = null;
        sprite.__cacheBitmapData = null;
    }
}