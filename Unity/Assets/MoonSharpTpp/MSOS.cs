using MoonSharp.Interpreter;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;

namespace MoonSharpTpp {
    //tex moonsharp doesnt provide os module
    //this is quick hacked together version of only the stuff mgstpp/ih uses.
    [MoonSharpUserData]
    class MSOS {
        public static void execute(string cmd) {
            System.Diagnostics.Process process = new System.Diagnostics.Process();
            System.Diagnostics.ProcessStartInfo startInfo = new System.Diagnostics.ProcessStartInfo();
            //startInfo.WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden;
            startInfo.FileName = "cmd.exe";
            startInfo.Arguments = "/C " + cmd;
            process.StartInfo = startInfo;
            process.Start();
            process.WaitForExit();
        }

        public static double time() {
            TimeSpan span = DateTime.Now.Subtract(new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc));
            return span.TotalSeconds;
        }

        public static double date(string format) {
            //tex TODO format
            return MSOS.time();
        }

        public static double clock() {
            Process prc = Process.GetCurrentProcess();
            return prc.TotalProcessorTime.TotalMilliseconds;
        }
    }
}
