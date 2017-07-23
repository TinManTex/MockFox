using System.Collections;
using System.Collections.Generic;
using UnityEngine;

using MoonSharp.Interpreter;
using MoonSharp.Interpreter.REPL;
using MoonSharp.Interpreter.Loaders;
using MoonSharpTpp;
using MoonSharp.Interpreter.Interop;
using System;

public class MockFoxManager : MonoBehaviour {
    public string mockFoxPath = null;//tex path of MockFox lua scripts
    public string foxLuaPath = null;//tex path of tpps scripts (qar luas)
    public string gamePath = null;//tex path of tpp

    public bool luaPrintToDebugLog = true;

    Script script;

    private bool SetModulePaths(List<string> modulePaths) {
        if (script != null) {
            ((ScriptLoaderBase)script.Options.ScriptLoader).ModulePaths = modulePaths.ToArray();
        }
        return true;
    }

    void Start () {
        if (mockFoxPath==null) {
            Debug.Log("WARNING: mockFoxPath==null");
            return;
        }

        if (foxLuaPath == null) {
            Debug.Log("WARNING: foxLuaPath==null");
            return;
        }

        if (gamePath == null) {
            Debug.Log("WARNING: gamePath==null");
            return;
        }

        //tex TODO: append trailing slash to paths if need be

        script = new Script();
        script.Options.ScriptLoader = new ReplInterpreterScriptLoader();

        //tex moonsharp doesnt use package.path :(
        //DEBUGNOW ((ScriptLoaderBase)script.Options.ScriptLoader).ModulePaths = new string[] {mockFoxPath + "?.lua"};
        //tex so InfCore calls SetModulePaths with it's additions to package.path
        script.Globals["SetModulePaths"] = (Func<List<string>,bool>)SetModulePaths;

        //tex lua print will output to Unity Debug.Log
        if (luaPrintToDebugLog) {
            script.Options.DebugPrint = s => {
                Debug.Log(s);
            };
        }

        Debug.Log("MockFoxManager: Register MoonSharpTpp modules");
        UserData.RegistrationPolicy = InteropRegistrationPolicy.Automatic;
  
        //tex register modules that moonsharp doesnt provide
        script.Globals["os"] = new MSOS();
        script.Globals["io"] = new MSIO();

        //tex register tpp c# modules
        Mission missionInstance = new Mission();
        script.Globals["Mission"] = missionInstance;

        //tex other lua host stuff that MockFox needs
        script.Globals["mockFoxPath"] = mockFoxPath;
        script.Globals["foxLuaPath"] = foxLuaPath;
        script.Globals["foxGamePath"] = gamePath;

        script.Globals["luaHostType"] = "MoonSharp";

        Debug.Log("MockFoxManager: run MockFox scripts");
        //tex run MockFox setup scripts
        try {
            DynValue chunk = script.LoadFile(mockFoxPath + "\\loadMockFox.lua");
            script.Call(chunk);
        }
        catch (ScriptRuntimeException ex) {
            Debug.Log(string.Format("ScriptRuntimeException :{0}", ex.DecoratedMessage));
        }

        Debug.Log("MockFoxManager: run tpp init.lua");
        try {
            DynValue chunk = script.LoadFile(foxLuaPath + "\\init.lua");//tex not quite able to load it straight yet
            script.Call(chunk);
        } catch (ScriptRuntimeException ex) {
            Debug.Log(string.Format("ScriptRuntimeException :{0}", ex.DecoratedMessage));
        }
        Debug.Log("MockFoxManager: run tpp start.lua");
        DynValue startChunk=null;
        try {
            startChunk = script.LoadFile(foxLuaPath + "\\Tpp\\start.lua");//tex not quite able to load it straight yet
        } catch (ScriptRuntimeException ex) {
            Debug.Log(string.Format("ScriptRuntimeException :{0}", ex.DecoratedMessage));
        }

        if (startChunk==null) {
            return;
        }

        DynValue coroutine = null;
        try { 
            coroutine = script.CreateCoroutine(startChunk);
        } catch (ScriptRuntimeException ex) {
            Debug.Log(string.Format("ScriptRuntimeException :{0}", ex.DecoratedMessage));
        }

        //tex wait till start couroutine done
        foreach (DynValue ret in coroutine.Coroutine.AsTypedEnumerable()) {
            
        }

        //tex test/example of actual utility of mockfox
        //TppMissionList.lua lists the location and mission fpks.
        //However the mission packs are often returned by a lua function depending on the mission code.
        //I've set up the Mission module (a Fox engine module) to work similar to how the fox engine handles it:
        //TppMissionList calls Mission.SetMissionPackagePathFunc to give it a reference to Table GetMissionPackagePath(missionCode), which will further run the lua functions that actually build the list for that missionCode
        //This is simply automagic to TppMissionList being loaded, and the Mission class I've added and registered with moonsharp
        //Also added to Mission is GetLocationPackPaths which actually calls GetMissionPackagePath via the provided referece and returns the table as a List<string>
        //List<string> packPaths = missionInstance.GetLocationPackPaths(script, 10);

        script.DoString("vars.locationCode=10");
        List<string> packPaths = missionInstance.GetMissionPackPaths(script, 30050);
        foreach (string path in packPaths) {
            Debug.Log(path);
        }

        Debug.Log("done");
    }
	
	void Update () {
		
	}
}
