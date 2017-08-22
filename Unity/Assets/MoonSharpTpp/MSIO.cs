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
            if (fileName==null) {
                error = "ERROR: fileName is nil";
                return null;
            }

            FileStream file = null;
            error = null;

            //tex only handling the IH/Tpp use cases
            if (mode == "r") {
                if (!File.Exists(fileName)) {
                    error = fileName + " not found";
                    return null;
                }

                try {
                    file = File.OpenRead(fileName);
                } catch(Exception ex) {
                    //tex convert errors to lua error
                    error = ex.ToString();
                    return null;
                }
            } else {
                if (mode == "w") {
                    try {
                        file = File.OpenWrite(fileName);
                    } catch(Exception ex) {
                        //tex convert errors to lua error
                        error = ex.ToString();
                        return null;
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
        //tex not a normal io function, but for IH
        public List<string> GetFiles(string path,string pattern) {
            List<string> files = new List<string>();
            if (Directory.Exists(path)) {
                files = Directory.GetFiles(path, pattern, SearchOption.AllDirectories).ToList<string>();
            }
            return files;
        }
    }
}
