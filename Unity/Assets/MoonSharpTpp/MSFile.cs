using MoonSharp.Interpreter;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace MoonSharpTpp {
    //tex moonsharp doesnt provide file module
    //this is quick hacked together version of only the stuff mgstpp/ih uses.
    [MoonSharpUserData]
    class MSFile {
        public string fileName;

        public MSFile(string _fileName) {
            fileName=_fileName;
        }

        public void close() {
            if (fileName != null) {
            }
        }

        public void write(string text) {// DEBUGNOW TODO variable list of parameters
            if (fileName != null) {
                File.WriteAllText(fileName, text);
            }
        }

        //tex only handling the IH/Tpp use cases
        public string read(string format) {
            if (fileName != null) {
                //if (format == "*a") {
                    return File.ReadAllText(fileName);
                //}
            }
            return "";
        }
    }
}
