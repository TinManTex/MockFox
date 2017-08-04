using GzsTool.Core.Utility;
using MoonSharp.Interpreter;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

//WORKAROUND: Already defining most of Fox module in lua
//but still need StrCode32
namespace MoonSharpTpp {
    [MoonSharpUserData]
    class HashingGzsTool {
        public static uint StrCode32(string text, bool removeExtension = true) {
            return (uint)Hashing.HashFileNameLegacy(text, false);
        }

        //DEBUGNOW TODO not sure whats going on
        //path32 bleh is same in engine, /Tpp/start.lua isnt
        public static uint PathFileNameCode32(string filePath) {
            //DEBUGNOW
            int index = filePath.IndexOf('.');
            // filePath = index == -1 ? filePath : filePath.Substring(0, index);

            //return (uint)Hashing.HashFileNameWithExtension(filePath);
            return (uint)Hashing.HashFileName(filePath,false);
        }
    }
}
