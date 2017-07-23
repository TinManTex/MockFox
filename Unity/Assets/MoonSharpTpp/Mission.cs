using MoonSharp.Interpreter;
using MoonSharp.Interpreter.Interop;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace MoonSharpTpp {
    [MoonSharpUserData]
    class Mission {
        DynValue locationPackagePathFunc;
        DynValue missionPackagePathFunc;

        public Mission() {
        }

        //tex from lua
        public int MISSION_FLAGS_FOB = 1;
        public int MISSION_FLAGS_MB = 2;
        public int ON_MESSAGE_RESULT_RESEND = 1;

        public void AddFinalizer() {

        }
        public void AddLocationFinalizer() {

        }
        public void CanStart() {

        }
        public void GetCurrentMessageResendCount() {

        }
        public void GetTextureLoadedRate() {

        }
        public bool IsBootedFromMgo() {
            return false;
        }
        public void LoadLocation() {

        }
        public void LoadMission() {

        }
        public void RegisterMissionCodeList() {

        }
        public void RequestToReload() {

        }
        public void SendMessage() {

        }
        public void SetLocationPackagePathFunc(DynValue func) {
            locationPackagePathFunc = func;
        }
        public void SetMissionPackagePathFunc(DynValue func) {
            missionPackagePathFunc = func;
        }
        public void SetMissionFlags() {

        }
        public void SetStageLoadLateEnabled() {

        }
        public void Start() {

        }
        public void StartFobGameDaemon() {

        }
        public void StartSystemMenuPause() {

        }
        public void SwitchApplication() {

        }

        //tex to lua
        [MoonSharpVisible(false)]
        public List<string> GetLocationPackPaths(Script script,int missionCode) {
            if (locationPackagePathFunc==null) {
                return null;
            }

            DynValue res = script.Call(locationPackagePathFunc, missionCode);
            if (res==null) {
                return null;
            }

            if (res.Table != null) {
                return res.ToObject<List<string>>();
            }

            return null;
        }
        [MoonSharpVisible(false)]
        public List<string> GetMissionPackPaths(Script script, int missionCode) {
            if (missionPackagePathFunc == null) {
                return null;
            }

            DynValue res = script.Call(missionPackagePathFunc, missionCode);
            if (res == null) {
                return null;
            }

            if (res.Table != null) {
                return res.ToObject<List<string>>();
            }

            return null;
        }
    }
}
