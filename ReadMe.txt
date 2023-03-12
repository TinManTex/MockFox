MockFox

MockFox is a framework to load/compile MGSV TPP lua scripts including Infinite Heaven outside of the games exe itself by providing mock versions of the mgstpp internal modules.
May be useful for analysing data in the scripts.
Infinite Heaven used it for it's AutoDoc which creates the Features and Options txt and html files.

If you just want to look at the generated fox modules for reference see /MockFoxLua/<game id>/

Terms:
Host - the lua vm/interpreter that will be loading/running the fox engine scripts. Ex LDT - Lua Development Tools, MoonSharp C# lua implementation, or MGSTPP.exe I guess.

Dependencies:

Complete set of lua files from data1.dat

If you want to run Infinite Heaven (not actually nessesary) you can get the full set by:
Grab from https://github.com/TinManTex/mgsv-deminified-lua
Unzip somewhere
Infinite Heaven
Unzip .mgsv, copy Assets,Tpp,init.lua into data1 luas folder, replacing any files.

Unity/MoonSharp:

MoonSharp (http://www.moonsharp.org/) Unity package
https://www.assetstore.unity3d.com/en/#!/content/33776

GzsTool.Core - for Fox.StrCode32 support

Files in this project:
/MockFoxLua/
	The majority of the mgstpp.exe lua facing modules mocked out, mostly empty functions and enum values, but enough to stop lua from complaining when reading the files.
/MockFoxLua/<game id>/
	Output of IHTeardown
	Only tpp has actually been tested running mockfox
/MockFoxLua/loadLDT.lua - for loading mockfox through Lua Development Tools, loads loadMockFox
/MockFoxLua/loadMockFox.lua - loaded by other hosts to actualy load MockFox - /MockFoxLua/<game id>/

/MGS_TPP/
	IHTearDown and supporting file for generating the mock modules, and some other analysis dumps.
	See header of IHTearDown.lua for more notes.

/Unity/
MockFoxManager.cs - unity script component that uses MoonSharp to load MockFoxLua and the mgstpp lua scripts.
/Unity/Assets/MoonSharpTpp - (minimal) support for io module (MoonSharp doesn't provide it) and other fox engine mock modules that can't be defined by lua alone.

Setup:

LDT only: 
Open MockFoxLua\loadLDT.lua
Edit foxGamePath,foxLuaPath,mockFoxPath to point to MGS_TPP game folder, data1 luas, MockFoxLuas respectively.
Run loadLDT

Unity:
Add MoonSharp unity package to project

Add GzsTool.Core assembly to project.

Copy the files in MockFox zip Unity\Assets to your projects Assets folder.
Add MockFoxManager.cs as a script component to a Unity entity.
Change Mock Fox Path, Fox Lua Path, Game Path to folder of Mock Fox luas, data1 luas, MGS_TOO game folder respectively.

Building:
Not nessesary (the generated files are already included), but IHTearDown.lua in MGS_TPP\mod\modules can be used with IH to generate MockModules.lua and vars.lua as well as dump some intermediary info by running DumpModules and DumpVars respectively while mgstpp/IH is loaded.

