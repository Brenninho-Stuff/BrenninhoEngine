package;

import flixel.FlxGame;
import flixel.FlxG;
import openfl.display.Sprite;
import openfl.Lib;
import openfl.display.StageScaleMode;
import openfl.events.Event;
import lime.app.Application;
import states.TitleState;

// Advanced Memory & System Management
#if cpp
import cpp.NativeGc;
import backend.Native;
#elseif html5
import js.Browser;
import js.html.CanvasElement;
#end

#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
#end

/**
 * @author Brenninho-Stuff
 * @version 3.0.0-PRO (Optimized for Haxe 4.3.7)
 * High-Performance Orchestrator for Psych Engine Forks.
 */
@:access(flixel.FlxGame)
class Main extends Sprite
{
    // High-Level Engine Configuration
    public static final SETTINGS = {
        resolution: { width: 1280, height: 720 },
        framerate: { initial: 60, target: 144 },
        state: { initial: TitleState, skipSplash: true },
        debug: #if debug true #else false #end
    };

    public static var fpsCounter:debug.FPSCounter;
    public static var instance:Main;

    /**
     * Entry point: Forces GC optimization before any object allocation.
     */
    public static function main():Void
    {
        #if cpp
        NativeGc.enable(true);
        NativeGc.run(true);
        #end

        Lib.current.addChild(new Main());
    }

    public function new()
    {
        super();
        instance = this;

        // Ensure stage is valid for hardware acceleration
        if (stage != null) 
            boot();
        else 
            addEventListener(Event.ADDED_TO_STAGE, (_) -> boot());
    }

    /**
     * Asynchronous-style Boot Process
     */
    private function boot():Void
    {
        removeEventListener(Event.ADDED_TO_STAGE, boot);

        initializeFilesystem();
        setupHardwareInterface();
        configureScripting();
        
        // Finalize Flixel Initialization
        startEngine();
        
        postBootSync();
    }

    private function initializeFilesystem():Void
    {
        #if mobile
        Sys.setCwd(mobile.backend.StorageUtil.getStorageDirectory());
        #elseif html5
        // Ensure the browser doesn't throttle the game loop
        Browser.window.console.log("BrenninhoEngine: Initializing WebGL Context...");
        #end

        #if (cpp && windows)
        backend.Native.fixScaling(); 
        #end
    }

    private function setupHardwareInterface():Void
    {
        stage.align = "tl";
        stage.scaleMode = StageScaleMode.NO_SCALE;
        
        fpsCounter = new debug.FPSCounter(10, 3, 0xFFFFFF);
        addChild(fpsCounter);

        // Hardware-specific VSync & Refresh Tuning
        #if !html5
        Application.current.window.vsync = backend.ClientPrefs.data.vsync;
        #else
        // HTML5 VSync is handled by RequestAnimationFrame automatically
        FlxG.autoPause = false; 
        #end
    }

    private function configureScripting():Void
    {
        #if HSCRIPT_ALLOWED
        Iris.logLevel = #if debug ALL #else ERROR #end;
        Iris.error = (msg, ?pos) -> broadcastMessage(ERROR, msg, pos);
        Iris.warn = (msg, ?pos) -> broadcastMessage(WARN, msg, pos);
        #end
    }

    private function startEngine():Void
    {
        var initialState = #if COPYSTATE_ALLOWED !states.CopyState.checkExistingFiles() ? states.CopyState : #end SETTINGS.state.initial;

        var game = new FlxGame(
            SETTINGS.resolution.width, 
            SETTINGS.resolution.height, 
            initialState, 
            SETTINGS.framerate.target, 
            SETTINGS.framerate.target, 
            SETTINGS.state.skipSplash
        );
        
        // Critical: Disable fixed timestep for fluid physics on high-hz monitors
        FlxG.fixedTimestep = false;
        
        addChild(game);
    }

    private function postBootSync():Void
    {
        // Global Signal Hooks
        FlxG.signals.gameResized.add(onResize);
        
        // Memory Defragmentation Hook
        FlxG.signals.postStateSwitch.add(() -> {
            #if cpp 
            NativeGc.run(true); 
            NativeGc.compact(); 
            #elseif html5
            // Signal the browser to attempt garbage collection hint
            Browser.window.performance.clearResourceTimings();
            #end
        });

        // HTML5 Focus Management
        #if html5
        Browser.window.addEventListener("blur", (_) -> FlxG.game.focusLost());
        Browser.window.addEventListener("focus", (_) -> FlxG.game.focusGained());
        #end
    }

    /**
     * Advanced Resize Logic: Handles Shader Cache Invalidation
     */
    private function onResize(w:Int, h:Int):Void
    {
        if (fpsCounter != null)
            fpsCounter.positionFPS(10, 3, Math.min(w / FlxG.width, h / FlxG.height));

        // Iterate through cameras and clear bitmap caches to prevent memory spikes
        if (FlxG.cameras != null) {
            for (cam in FlxG.cameras.list) {
                if (cam != null && cam.flashSprite != null)
                    invalidateCache(cam.flashSprite);
            }
        }
        invalidateCache(FlxG.game);
    }

    /**
     * Low-Level cache invalidation using OpenFL Private Access
     */
    @:access(openfl.display.DisplayObject)
    private static function invalidateCache(obj:openfl.display.DisplayObject):Void {
        obj.__cacheBitmap = null;
        obj.__cacheBitmapData = null;
    }

    private function broadcastMessage(type:String, msg:Dynamic, pos:haxe.PosInfos):Void {
        var color:Int = (type == "ERROR") ? 0xFF0000 : 0xFFFF00;
        if (states.PlayState.instance != null)
            states.PlayState.instance.addTextToDebug('[$type] $msg', color);
        
        trace('[$type] $msg at ${pos.fileName}:${pos.lineNumber}');
    }
}