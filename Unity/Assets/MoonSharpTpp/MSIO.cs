using MoonSharp.Interpreter;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace MoonSharpTpp {
    //tex moonsharp doesnt provide io module
    //this is quick hacked together version of only the stuff mgstpp/ih uses.
    [MoonSharpUserData]
    class MSIO {
        public MSFile open(string fileName, string mode, out string error) {
            FileStream file = null;
            error = null;

            //tex only handling the IH/Tpp use cases
            if (mode == "r") {
                try {
                    file = File.OpenRead(fileName);
                }
                catch(Exception ex) {
                    //tex convert errors to lua error
                    error = ex.ToString();
                }
            } else {
                if (mode == "w") {
                    try {
                        file = File.OpenWrite(fileName);
                    } catch(Exception ex) {
                        //tex convert errors to lua error
                        error = ex.ToString();
                    }
                }
            }

            if (file!=null) {
                file.Close();
                return new MSFile(fileName);
            } else {
                return null;
            }
        }
    }
}
