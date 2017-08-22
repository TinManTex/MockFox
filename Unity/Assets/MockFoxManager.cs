using System.Collections;
using System.Collections.Generic;
using UnityEngine;

using MoonSharp.Interpreter;
using MoonSharp.Interpreter.REPL;
using MoonSharp.Interpreter.Loaders;
using MoonSharpTpp;
using MoonSharp.Interpreter.Interop;
using System;
using System.IO;

[ExecuteInEditMode]
public class MockFoxManager : MonoBehaviour {
    public enum Stages {
        NONE,
        ERROR,
        BROKEN,//tex idle after error
        BEGIN,
        SETUP_MOONSHARP,
        LOAD_MOCKFOX,
        LOAD_INIT,
        LOAD_START,
        LOADING_START,
        ALL_LOADED,
        DOTESTS,
        READY,//tex ready to be worked with, technically ALL_LOADED is that point, but it's usefull to have the tests stage first.
        RUNNING,//tex nothing for now (stops at READY), but if it needs to be taken to the point of mgstpp update emulation.
    }

    public string mockFoxPath = null;//tex path of MockFox lua scripts
    public string foxLuaPath = null;//tex path of tpps scripts (qar luas)
    public string gamePath = null;//tex path of tpp

    public bool luaPrintToDebugLog = true;

    public Script script = null;
    public Stages stage = Stages.NONE;

    DynValue coroutine = null;
    int returnCount = 0;
    System.Diagnostics.Stopwatch fullLoadStopwatch = new System.Diagnostics.Stopwatch(); //DEBUGNOW
    System.Diagnostics.Stopwatch coroutineStopwatch = new System.Diagnostics.Stopwatch(); //DEBUGNOW
    System.Diagnostics.Stopwatch stageStopwatch = new System.Diagnostics.Stopwatch(); //DEBUGNOW

    int currentIndex = -1;//DEBUGNOW

    private bool SetModulePaths(List<string> modulePaths) {
        if (script != null) {
            ((ScriptLoaderBase)script.Options.ScriptLoader).ModulePaths = modulePaths.ToArray();
        }
        return true;
    }

    private static string FixupPath(string path) {
        path = path.Replace('\\', '/');
        while (path.EndsWith(Path.AltDirectorySeparatorChar.ToString())) {
            path = path.Substring(0, path.Length - 1);
        }

        path = path + "/";
        return path;
    }

    private static bool IsRelative(string path) {
        if (Path.IsPathRooted(path)) {
            string c = path.Substring(0, 1);
            if (c != "\\" && c != "/") {
                return false;
            }
        }

        return true;
    }

    private void OnEnable() {
        UnityEditor.EditorApplication.update += Update;//tex to have it update in editor
    }

    void Start() {
        stage = Stages.BEGIN;//tex currently auto start on entity start, can remove this and manually start it by changine stage in inspector.
    }

    void Update() {
        stageStopwatch.Reset();
        stageStopwatch.Start();

        //tex would like a dict to delegate, but would have to figure out unities serialization
        Stages changeStage = Stages.NONE;
        switch (stage) {
            case Stages.ERROR:
                changeStage = Error();
                break;
            case Stages.BROKEN:
                changeStage = Broken();
                break;
            case Stages.BEGIN:
                changeStage = Begin();
                break;
            case Stages.SETUP_MOONSHARP:
                changeStage = SetupMoonSharp();
                break;
            case Stages.LOAD_MOCKFOX:
                changeStage = LoadMockFox();
                break;
            case Stages.LOAD_INIT:
                changeStage = LoadInit();
                break;
            case Stages.LOAD_START:
                changeStage = LoadStart();
                break;
            case Stages.LOADING_START:
                changeStage = LoadingStart();
                break;
            case Stages.ALL_LOADED:
                changeStage = AllLoaded();
                break;
            case Stages.DOTESTS:
                changeStage = DoTests();
                break;
            case Stages.READY:
                changeStage = Run();
                break;
            default:
                break;
        }

        stageStopwatch.Stop();
        if (stage != Stages.NONE && stage != Stages.BROKEN && stage != Stages.READY) {
            Debug.Log("MockFoxManager: stage " + stage + " time:" + coroutineStopwatch.Elapsed);
        }

        if (changeStage != Stages.NONE) {
            Debug.Log("MockFoxManager: Change stage from " + stage + " to " + changeStage);
            stage = changeStage;
        }
    }

    Stages Error() {
        Debug.Log("MockFoxManger: stage:ERROR");
        return Stages.BROKEN;
    }

    Stages Broken() {
        return Stages.NONE;
    }

    Stages Begin() {
        if (mockFoxPath == null) {
            Debug.Log("WARNING: mockFoxPath==null");
            return Stages.ERROR;
        }

        if (foxLuaPath == null) {
            Debug.Log("WARNING: foxLuaPath==null");
            return Stages.ERROR;
        }

        if (gamePath == null) {
            Debug.Log("WARNING: gamePath==null");
            return Stages.ERROR;
        }

        fullLoadStopwatch.Start();

        //tex path butchering
        mockFoxPath = FixupPath(mockFoxPath);
        foxLuaPath = FixupPath(foxLuaPath);
        gamePath = FixupPath(gamePath);
        //tex gamePath is used to construct a packages.path line similar to mgstpp, so build full path if it was relative
        if (IsRelative(gamePath)) {
            var unityPath = Application.dataPath;
            //TODO: datapath is aparently different for different platforms and also editor vs player
            //https://docs.unity3d.com/ScriptReference/Application-dataPath.html
            unityPath += "/";//tex for some reason GetParent kills two folders if path isn't capped, guess it assumes no cap = filename
            DirectoryInfo parentDir = Directory.GetParent(unityPath);
            unityPath = parentDir.Parent.FullName;
            Debug.Log("unityPath=" + unityPath);
            var sep = "/";
            if (Path.IsPathRooted(gamePath)) {
                sep = "";
            }
            gamePath = unityPath + sep + gamePath;
        }

        Debug.Log("mockFoxPath=" + mockFoxPath);
        Debug.Log("foxLuaPath=" + foxLuaPath);
        Debug.Log("gamePath=" + gamePath);

        //tex there's not going to be any real consistancy here, but making some token attempt.
        gamePath = gamePath.Replace("/", "\\");

        return Stages.SETUP_MOONSHARP;
    }

    Stages SetupMoonSharp() {
        script = new Script();
        script.Options.ScriptLoader = new ReplInterpreterScriptLoader();

        //tex moonsharp doesnt use package.path :(
        //DEBUGNOW ((ScriptLoaderBase)script.Options.ScriptLoader).ModulePaths = new string[] {mockFoxPath + "?.lua"};
        //tex so InfCore calls SetModulePaths with it's additions to package.path
        script.Globals["SetModulePaths"] = (Func<List<string>, bool>)SetModulePaths;

        //tex lua print will output to Unity Debug.Log
        if (luaPrintToDebugLog) {
            script.Options.DebugPrint = s => {
                Debug.Log(s);
            };
        }

        Debug.Log("MockFoxManager: Register MoonSharpTpp modules");
        UserData.RegistrationPolicy = InteropRegistrationPolicy.Default;//InteropRegistrationPolicy.Automatic;//DEBUGNOW
        UserData.RegisterAssembly();//DEBUGNOW

        //tex register modules that moonsharp doesnt provide
        script.Globals["os"] = new MSOS();
        script.Globals["io"] = new MSIO();

        //tex should be part of Fox module, but I'm already defining a bunch of that in lua
        script.Globals["HashingGzsTool"] = new HashingGzsTool();

        //tex register tpp c# modules
        script.Globals["Mission"] = new Mission();


        //tex other lua host stuff that MockFox needs
        script.Globals["mockFoxPath"] = mockFoxPath;
        script.Globals["foxLuaPath"] = foxLuaPath;
        script.Globals["foxGamePath"] = gamePath;

        script.Globals["luaHostType"] = "MoonSharp";

        return Stages.LOAD_MOCKFOX;
    }

    Stages LoadMockFox() {
        Debug.Log("MockFoxManager: run MockFox scripts");
        try {
            DynValue chunk = script.LoadFile(mockFoxPath + "/loadMockFox.lua");
            script.Call(chunk);
        } catch (Exception ex) {
            Debug.LogError(string.Format("{0}", ex));
            return Stages.ERROR;
        }

        return Stages.LOAD_INIT;
    }

    Stages LoadInit() {
        Debug.Log("MockFoxManager: run tpp init.lua");
        try {
            DynValue chunk = script.LoadFile(foxLuaPath + "/init.lua");
            script.Call(chunk);
        } catch (Exception ex) {
            Debug.LogError(string.Format("{0}", ex));
            return Stages.ERROR;
        }

        return Stages.LOAD_START;
    }

    Stages LoadStart() {
        Debug.Log("MockFoxManager: start.lua load");
        DynValue startChunk = null;
        try {
            startChunk = script.LoadFile(foxLuaPath + "/Tpp/start.lua");
        } catch (Exception ex) {
            Debug.LogError(string.Format("{0}", ex));
            return Stages.ERROR;
        }

        if (startChunk == null) {
            return Stages.ERROR;
        }

        Debug.Log("MockFoxManager: start.lua run");

        try {
            coroutine = script.CreateCoroutine(startChunk);
        } catch (Exception ex) {
            Debug.LogError(string.Format("{0}", ex));
            return Stages.ERROR;
        }

        returnCount = 0;

        return Stages.LOADING_START;
    }

    //tex start.lua is loaded a coroutine, this lets Unity run when start yields
    Stages LoadingStart() {
        if (coroutine == null) {
            Debug.Log("MockFoxManager: start coroutine==null");
            return Stages.ERROR;
        }

        coroutineStopwatch.Reset();
        coroutineStopwatch.Start();

        //tex wait till start couroutine done
        foreach (DynValue ret in coroutine.Coroutine.AsTypedEnumerable()) {
            returnCount++;
            coroutineStopwatch.Stop();
            //Debug.Log("MockFoxManager: start.lua coroutine return #" + returnCount + " in " + coroutineStopwatch.Elapsed);//DEBUGNOW
            return Stages.NONE;
        }

        coroutine = null;
        returnCount = 0;

        Debug.Log("MockFoxManager: start.lua done");
        return Stages.ALL_LOADED;
    }

    Stages AllLoaded() {
        fullLoadStopwatch.Start();

        Debug.Log("MockFoxManager: MockFox + tpp scripts loaded in " + fullLoadStopwatch.Elapsed);
        return Stages.DOTESTS;
    }

    Stages DoTests() {
        //tex test/example of actual utility of mockfox
        //TppMissionList.lua lists the location and mission fpks.
        //However the mission packs are often returned by a lua function depending on the mission code.
        //I've set up the Mission module (a Fox engine module) to work similar to how the fox engine handles it:
        //TppMissionList calls Mission.SetMissionPackagePathFunc to give it a reference to Table GetMissionPackagePath(missionCode), which will further run the lua functions that actually build the list for that missionCode
        //This is simply automagic to TppMissionList being loaded, and the Mission class I've added and registered with moonsharp
        //Also added to Mission is GetLocationPackPaths which actually calls GetMissionPackagePath via the provided referece and returns the table as a List<string>
        //List<string> packPaths = missionInstance.GetLocationPackPaths(script, 10);

        script.DoString("vars.locationCode=10");
        Mission missionInstance = (Mission)script.Globals["Mission"];
        List<string> packPaths = missionInstance.GetMissionPackPaths(script, 30050);
        foreach (string path in packPaths) {
            Debug.Log(path);
        }

        //tex TEST
        //TODO: ScriptRuntimeException: attempt to index a nil value when running on unmodded tpp script set
        /*
        script.DoString(@";
        InfCore.PrintInspect(Fox.StrCode32('bleh'), 'str32 bleh')
        InfCore.PrintInspect(Fox.PathFileNameCode32('bleh'), 'path32 bleh')
        InfCore.PrintInspect(Fox.PathFileNameCode32('/Tpp/start.lua'), 'path32 /Tpp/start.lua')
        InfCore.PrintInspect(Fox.PathFileNameCode32('/Tpp/start'), 'path32 /Tpp/start')
        ");
        */

        //tex TEST error
        script.DoString(@"
        local file,error=io.open('c:/doesnotexist.txt','r')
        print(error)
        ");

        Debug.Log("Tests done");

        return Stages.READY;
    }

    //tex all loaded/idle state
    Stages Run() {
        return Stages.NONE;
    }

    Stages LoadStartP2() {
        Debug.Log("MockFoxManager: startp2.lua load requires");//DEBUGNOW

        //DEBUGNOW
        List<string> requires = new List<string>{
          "/Assets/tpp/script/lib/InfRequiresStart.lua",
          "/Assets/tpp/script/lib/TppDefine.lua",
          "/Assets/tpp/script/lib/TppMath.lua",
          "/Assets/tpp/script/lib/TppSave.lua",
          "/Assets/tpp/script/lib/TppLocation.lua",
          "/Assets/tpp/script/lib/TppSequence.lua",
          "/Assets/tpp/script/lib/TppWeather.lua",
          "/Assets/tpp/script/lib/TppDbgStr32.lua",
          "/Assets/tpp/script/lib/TppDebug.lua",
          "/Assets/tpp/script/lib/TppClock.lua",
          "/Assets/tpp/script/lib/TppUI.lua",
          "/Assets/tpp/script/lib/TppResult.lua",
          "/Assets/tpp/script/lib/TppSound.lua",
          "/Assets/tpp/script/lib/TppTerminal.lua",
          "/Assets/tpp/script/lib/TppMarker.lua",
          "/Assets/tpp/script/lib/TppRadio.lua",
          "/Assets/tpp/script/lib/TppPlayer.lua",
          "/Assets/tpp/script/lib/TppHelicopter.lua",
          "/Assets/tpp/script/lib/TppScriptBlock.lua",
          "/Assets/tpp/script/lib/TppMission.lua",
          "/Assets/tpp/script/lib/TppStory.lua",
          "/Assets/tpp/script/lib/TppDemo.lua",
          "/Assets/tpp/script/lib/TppEnemy.lua",
          "/Assets/tpp/script/lib/TppGeneInter.lua",
          "/Assets/tpp/script/lib/TppInterrogation.lua",
          "/Assets/tpp/script/lib/TppGimmick.lua",
          "/Assets/tpp/script/lib/TppMain.lua",
          "/Assets/tpp/script/lib/TppDemoBlock.lua",
          "/Assets/tpp/script/lib/TppAnimalBlock.lua",
          "/Assets/tpp/script/lib/TppCheckPoint.lua",
          "/Assets/tpp/script/lib/TppPackList.lua",
          "/Assets/tpp/script/lib/TppQuest.lua",
          "/Assets/tpp/script/lib/TppTrap.lua",
          "/Assets/tpp/script/lib/TppReward.lua",
          "/Assets/tpp/script/lib/TppRevenge.lua",
          "/Assets/tpp/script/lib/TppReinforceBlock.lua",
          "/Assets/tpp/script/lib/TppEneFova.lua",
          "/Assets/tpp/script/lib/TppFreeHeliRadio.lua",
          "/Assets/tpp/script/lib/TppHero.lua",
          "/Assets/tpp/script/lib/TppTelop.lua",
          "/Assets/tpp/script/lib/TppRatBird.lua",
          "/Assets/tpp/script/lib/TppMovie.lua",
          "/Assets/tpp/script/lib/TppAnimal.lua",
          "/Assets/tpp/script/lib/TppException.lua",
          "/Assets/tpp/script/lib/TppTutorial.lua",
          "/Assets/tpp/script/lib/TppLandingZone.lua",
          "/Assets/tpp/script/lib/TppCassette.lua",
          "/Assets/tpp/script/lib/TppEmblem.lua",
          "/Assets/tpp/script/lib/TppDevelopFile.lua",
          "/Assets/tpp/script/lib/TppPaz.lua",
          "/Assets/tpp/script/lib/TppRanking.lua",
          "/Assets/tpp/script/lib/TppTrophy.lua",
          "/Assets/tpp/script/lib/TppMbFreeDemo.lua",
          "/Assets/tpp/script/lib/InfButton.lua",
          "/Assets/tpp/script/lib/InfModules.lua",
          "/Assets/tpp/script/lib/InfMain.lua",
          "/Assets/tpp/script/lib/InfMenu.lua",
          "/Assets/tpp/script/lib/InfEneFova.lua",
          "/Assets/tpp/script/lib/InfRevenge.lua",
          "/Assets/tpp/script/lib/InfFova.lua",
          "/Assets/tpp/script/lib/InfLZ.lua",
          "/Assets/tpp/script/lib/InfPersistence.lua",
          "/Assets/tpp/script/lib/InfHooks.lua",
            };

        currentIndex = currentIndex++;
        if (currentIndex > requires.Count) {
            return Stages.LOADING_START;
        }

        Debug.Log("!!! Load " + requires[currentIndex]);

        try {
            DynValue chunk = script.LoadFile(foxLuaPath + requires[currentIndex]);
            script.Call(chunk);
        } catch (Exception ex) {
            Debug.LogError(string.Format("{0}", ex));
            return Stages.ERROR;
        }

        return Stages.NONE;
    }

}
