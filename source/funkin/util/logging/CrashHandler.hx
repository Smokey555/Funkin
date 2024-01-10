package funkin.util.logging;

import openfl.Lib;
import openfl.events.UncaughtErrorEvent;
import flixel.util.FlxSignal.FlxTypedSignal;

/**
 * A custom crash handler that writes to a log file and displays a message box.
 */
@:nullSafety
class CrashHandler
{
  public static final LOG_FOLDER = 'logs';

  /**
   * Called before exiting the game when a standard error occurs, like a thrown exception.
   * @param message The error message.
   */
  public static var errorSignal(default, null):FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

  /**
   * Called before exiting the game when a critical error occurs, like a stack overflow or null object reference.
   * CAREFUL: The game may be in an unstable state when this is called.
   * @param message The error message.
   */
  public static var criticalErrorSignal(default, null):FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

  /**
   * Initializes
   */
  public static function initialize():Void
  {
    trace('[LOG] Enabling standard uncaught error handler...');
    Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);

    #if cpp
    trace('[LOG] Enabling C++ critical error handler...');
    untyped __global__.__hxcpp_set_critical_error_handler(onCriticalError);
    #end
  }

  /**
   * Called when an uncaught error occurs.
   * This handles most thrown errors, and is sufficient to handle everything alone on HTML5.
   * @param error Information on the error that was thrown.
   */
  static function onUncaughtError(error:UncaughtErrorEvent):Void
  {
    try
    {
      errorSignal.dispatch(generateErrorMessage(error));

      #if sys
      logError(error);
      #end

      displayError(error);
    }
    catch (e:Dynamic)
    {
      trace('Error while handling crash: ' + e);
    }
  }

  static function onCriticalError(message:String):Void
  {
    try
    {
      criticalErrorSignal.dispatch(message);

      #if sys
      logErrorMessage(message, true);
      #end

      displayErrorMessage(message);
    }
    catch (e:Dynamic)
    {
      trace('Error while handling crash: $e');

      trace('Message: $message');
    }
  }

  static function displayError(error:UncaughtErrorEvent):Void
  {
    displayErrorMessage(generateErrorMessage(error));
  }

  static function displayErrorMessage(message:String):Void
  {
    lime.app.Application.current.window.alert(message, "Fatal Uncaught Exception");
  }

  #if sys
  static function logError(error:UncaughtErrorEvent):Void
  {
    logErrorMessage(generateErrorMessage(error));
  }

  static function logErrorMessage(message:String, critical:Bool = false):Void
  {
    FileUtil.createDirIfNotExists(LOG_FOLDER);

    sys.io.File.saveContent('$LOG_FOLDER/crash${critical ? '-critical' : ''}-${DateUtil.generateTimestamp()}.log', buildCrashReport(message));
  }

  static function buildCrashReport(message:String):String
  {
    var fullContents:String = '=====================\n';
    fullContents += ' Funkin Crash Report\n';
    fullContents += '=====================\n';

    fullContents += '\n';

    fullContents += 'Generated by: ${Constants.GENERATED_BY}\n';
    fullContents += 'System timestamp: ${DateUtil.generateTimestamp()}\n';
    var driverInfo = FlxG?.stage?.context3D?.driverInfo ?? 'N/A';
    fullContents += 'Driver info: ${driverInfo}\n';
    fullContents += 'Platform: ${Sys.systemName()}\n';

    fullContents += '\n';

    fullContents += '=====================\n';

    fullContents += 'Haxelibs: \n';

    for (lib in Constants.LIBRARY_VERSIONS)
    {
      fullContents += '- ${lib}\n';
    }

    fullContents += '\n';

    fullContents += '=====================\n';

    fullContents += '\n';

    fullContents += message;

    fullContents += '\n';

    return fullContents;
  }
  #end

  static function generateErrorMessage(error:UncaughtErrorEvent):String
  {
    var errorMessage:String = "";
    var callStack:Array<haxe.CallStack.StackItem> = haxe.CallStack.exceptionStack(true);

    errorMessage += '${error.error}\n';

    for (stackItem in callStack)
    {
      switch (stackItem)
      {
        case FilePos(innerStackItem, file, line, column):
          errorMessage += '  in ${file}#${line}';
          if (column != null) errorMessage += ':${column}';
        case CFunction:
          errorMessage += '[Function] ';
        case Module(m):
          errorMessage += '[Module(${m})] ';
        case Method(classname, method):
          errorMessage += '[Function(${classname}.${method})] ';
        case LocalFunction(v):
          errorMessage += '[LocalFunction(${v})] ';
      }
      errorMessage += '\n';
    }

    return errorMessage;
  }

  public static function queryStatus():Void
  {
    @:privateAccess
    var currentStatus = Lib.current.stage.__uncaughtErrorEvents.__enabled;
    trace('ERROR HANDLER STATUS: ' + currentStatus);

    #if openfl_enable_handle_error
    trace('Define: openfl_enable_handle_error is enabled');
    #else
    trace('Define: openfl_enable_handle_error is disabled');
    #end

    #if openfl_disable_handle_error
    trace('Define: openfl_disable_handle_error is enabled');
    #else
    trace('Define: openfl_disable_handle_error is disabled');
    #end
  }

  public static function induceBasicCrash():Void
  {
    throw "This is an example of an uncaught exception.";
  }
}
