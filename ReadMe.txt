MockFox is a collection of related projects based around Mock versions of the exe-side modules of MGSV.

Mock modules - the output of IHTearDown, a collated version of this is used by LoadMockFox, or just useful as a reference to the tpp exe lua api.
See /Generated/<game id>/mockModules/

If that's all your interested in you can ignore the other projects/the rest of this document.

Info - various mgsv info gathered from other processes or other people, some of which is processed by IHTearDown

IHTearDown - An IH module for generating the Mock modules from the running game and some other analysis stuff.
A run of its output is in /Generated/

LoadMockFox - a loader/glue that's complete enough to load the games lua scripts using the Mock modules via a lua interpreter external from the game.

It's robust enough to load the game scripts and Infinite Heavens scripts and was used for its AutoDoc function which generated the Features And Options documentation by reading the menu structure and help strings.


Terms:
Host - the lua vm/interpreter that will be loading/running the fox engine scripts. Ex LDT - Lua Development Tools, MoonSharp C# lua implementation, or MGSTPP.exe I guess.

Dependencies:

Complete set of lua files from data1.dat

If you want to run Infinite Heaven (not actually nessesary) you can get the full set by:
Grab from https://github.com/TinManTex/InfiniteHeaven/tree/master/tpp
Combine data1_dat-lua and data1_dat-lua-ih


Unity/MoonSharp:

MoonSharp (http://www.moonsharp.org/) Unity package
https://www.assetstore.unity3d.com/en/#!/content/33776

GzsTool.Core - for Fox.StrCode32 support

Files in this project:
/Generated/{game id}/
	Output of IHTearDown
	/mockModulesAsGlobal/
		Individual mock module lua files that self declare themselves as Global.
		You can use the vscode lua language server extension and add the folder in Settings > Lua > Workspace: Library 
		to quiet a bunch of warnings about Undefined globals when working with tpp lua files.
	/varsAsGlobal/
		vars,gvars,svars as global modules so they can be used in vscode in the same manner as mentioned above.

/Info/
	various mgsv info gathered from other processes or other people, some of which is processed by IHTearDown
	TODO: document the files

/MockFoxLua/
	The majority of the mgstpp.exe lua facing modules mocked out, mostly empty functions and enum values, but enough to stop lua from complaining when reading the files.
	/<game id>/
	Currently runs on a single file of collated mock modules output by IHTeardown.  
	Only tpp has actually been tested running mockfox

	/loadLDT.lua - for loading mockfox through Lua Development Tools, loads loadMockFox
	/loadMockFox.lua - loaded by other hosts to actualy load MockFox - /MockFoxLua/<game id>/


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

