package flxanimate.animate;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.math.FlxMatrix;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.util.FlxStringUtil;
import flxanimate.animate.SymbolParameters;
import flxanimate.data.AnimationData;
import haxe.extern.EitherType;
import openfl.geom.ColorTransform;
#if FLX_SOUND_SYSTEM
import flixel.system.FlxSound;
#end

class FlxAnimateAnimation implements IFlxDestroyable
{
	public var instance:FlxElement;
	public var frameRate(default, set):Float;

	/**
	 * Keeps track of the current frame of animation.
	 * This is NOT an index into the tile sheet, but the frame number in the animation object.
	 */
	public var curFrame(default, set):Int = 0;

	/**
	 * Accessor for `frames.length`
	 */
	public var numFrames(get, never):Int;

	/**
	 * Seconds between frames (inverse of the framerate)
	 *
	 * Note: `FlxFrameCollections` and `FlxAtlasFrames` may have their own duration set per-frame,
	 * those values will override this value.
	 */
	public var frameDuration(default, null):Float = 0;

	/**
	 * Whether the current animation has finished.
	 */
	public var finished(default, null):Bool = true;

	/**
	 * Whether the current animation is at the end aka the last frame.
	 * Works both when looping and reversed.
	**/
	public var isAtEnd(get, never):Bool;

	/**
	 * Whether the current animation gets updated or not.
	 */
	public var paused:Bool = true;

	/**
	 * Whether or not the animation is looped.
	 */
	public var looped(default, null):Bool = true;

	/**
	 * The custom loop point for this animation.
	 * This allows you to skip the first few frames of an animation when looping.
	 */
	public var loopPoint:Int = 0;

	/**
	 * Whether or not this animation is being played backwards.
	 */
	public var reversed(default, null):Bool = false;

	/**
	 * Whether or not the frames of this animation are horizontally flipped
	 */
	public var flipX:Bool = false;

	/**
	 * Whether or not the frames of this animation are vertically flipped
	 */
	public var flipY:Bool = false;

	/**
	 * Internal, used to time each frame of animation.
	 */
	var _frameTimer:Float = 0;

	/**
	 * Internal, used to wait the frameDuration at the end of the animation.
	 */
	var _frameFinishedEndTimer:Float = 0;

	/**
	 * How fast or slow time should pass for this animation.
	 *
	 * Similar to `FlxAnimationController`'s `timeScale`, but won't effect other animations.
	 * @since 5.4.1
	 */
	public var timeScale:Float = 1.0;

	public var name:String;

	var parent:FlxAnim;

	public var onFinish:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var onFinishEnd:FlxTypedSignal<Void->Void> = new FlxTypedSignal();
	public var onPlay:FlxTypedSignal<String->Bool->Bool->Int->Void> = new FlxTypedSignal();
	public var onLoop:FlxTypedSignal<Void->Void> = new FlxTypedSignal();

	public function new(parent:FlxAnim, name:String, instance:FlxElement, frameRate:Float, looped:Bool = true, flipX:Bool = false, flipY:Bool = false)
	{
		this.parent = parent;
		this.name = name;
		this.instance = instance;
		this.frameRate = frameRate;
		this.looped = looped;
		this.flipX = flipX;
		this.flipY = flipY;
	}

	public function play(Force:Bool = false, Reversed:Bool = false, Frame:Int = 0)
	{
	}

	public function restart():Void
	{
		play(true, reversed);
	}

	public function stop():Void
	{
		finished = true;
		paused = true;
	}

	public function reset():Void
	{
		stop();
		curFrame = reversed ? (numFrames - 1) : 0;
	}

	public function finish():Void
	{
		stop();
		curFrame = reversed ? 0 : (numFrames - 1);
	}

	public function pause():Void
	{
		paused = true;
	}

	public inline function resume():Void
	{
		paused = false;
	}

	public function reverse():Void
	{
		reversed = !reversed;
		if (finished)
			play(false, reversed);
	}

	inline function _doFinishedEndCallback():Void
	{
		parent.onFinishEnd.dispatch(name);
		onFinishEnd.dispatch();
	}

	public function update(elapsed:Float)
	{
		if (isDestroyed)
			return;
		if (paused)
			return;

		if (_frameFinishedEndTimer > 0)
		{
			_frameFinishedEndTimer -= elapsed * timeScale;
			if (_frameFinishedEndTimer <= 0)
			{
				_frameFinishedEndTimer = 0;
				_doFinishedEndCallback();
			}
		}
		if (finished)
			return;

		var curFrameDuration = getCurrentFrameDuration();
		if (curFrameDuration == 0)
			return;

		_frameTimer += elapsed * timeScale;
		while (_frameTimer > frameDuration && !finished)
		{
			_frameTimer -= frameDuration;
			if (reversed)
			{
				if (looped && curFrame == loopPoint)
				{
					curFrame = numFrames - 1;
					parent.fireLoopCallback(name);
					onLoop.dispatch();
				}
				else
					curFrame--;
			}
			else
			{
				if (looped && curFrame == numFrames - 1)
				{
					curFrame = loopPoint;
					parent.fireLoopCallback(name);
					onLoop.dispatch();
				}
				else
					curFrame++;
			}

			// prevents null ref when the sprite is destroyed on finishCallback (#2782)
			if (finished)
				break;

			curFrameDuration = getCurrentFrameDuration();
		}
	}

	function getCurrentFrameDuration()
	{
		@:privateAccess
		final curframeDuration = instance._parent.duration;
		// final curframeDuration = parent.getFrameDuration(frames[curFrame]);
		return curframeDuration > 0 ? curframeDuration : frameDuration;
	}

	var isDestroyed:Bool = false;

	public function destroy()
	{
		isDestroyed = true;
		instance = FlxDestroyUtil.destroy(instance);
		onFinish = FlxDestroyUtil.destroy(onFinish);
		onFinishEnd = FlxDestroyUtil.destroy(onFinishEnd);
	}

	inline function set_frameRate(value:Float):Float
	{
		frameDuration = (value > 0 ? 1.0 / value : 0);
		return frameRate = value;
	}

	inline function get_isAtEnd()
	{
		return reversed ? curFrame == 0 : curFrame == numFrames - 1;
	}

	inline function get_numFrames()
	{
		@:privateAccess
		return instance._parent._parent._keyframes.length;
	}

	inline function set_curFrame(v:Int)
	{
		// TODO: fix this
		return curFrame = v;
		//@:privateAccess
		//return instance._parent._parent.curFrame = v;
	}
}
