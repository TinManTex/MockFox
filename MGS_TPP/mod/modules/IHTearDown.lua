--DEBUGWIP
--IHTearDown.lua
--Dumps data from mgsv globals
--Builds mock modules.
--Requires:
--IHGenKnownModuleNames
--IHGenModuleReferences
--to be put in mod\modules
--run foxTearDownMenu > DoTearDown , when at least in ACC

--TODO: verify that module logging / BuildModuleRefsFromExeLog covers everything then depreciate IHGenModuleReferences

--tex NOTE internal C tables/modules exposed from MGS_TPP.exe are kinda funky,
--(see ghidra, calls to AddCFuncToModule, AddEnumToModule)
--a few are normal, plain text keys as you'd expect.
--most are doing something with indexing metatables via some custom class binding i guess
--the most common is fox table (for want of an actual term)
--module having [some-number] entries
--module having entry which has [some-number] entries
--some-number doesnt seem to be strcode32, might possibly be luastring hash itself --TODO: figure it out
--TODO: figure out any difference between entries in root vs in [-285212671]
--possibly enums vs c funcs
--going by Results from CheckFoxTableKeysAccountedFor, which seems to account for all AddCFuncToModule2 functions in root of a module, 
--with enums unnacounted for, but matching the number of entries in [-285212671] of a module
--but then PlayerVars which has var type entries has them in [-285212671]

--many have a _classname string, these have plain text keys/dont have the some-number indirection

--theres also a [-285212672]=some-number (usually =4,  sometimes 0, any other values?), but dont know what it represents

--REF
--WeatherManager = <345>{
--  [-285212672] = 4,--tex unknown
--  [-285212671] = {--tex identifies a table of some-number entries. --Results from CheckFoxTableKeysAccountedFor suggests this is the enum table
--    [7955555] = <function 5831>,
--    [16841280] = <function 5832>,
--    [27347291] = <function 5833>,
--    [32365128] = <function 5834>,
--    [44558204] = <function 5835>,
--    [77837453] = <function 5836>,
--    [96882270] = <function 5837>,
--    [179540398] = <function 5838>,
--    [184160756] = <function 5839>,
--    [226237853] = <function 5840>
--  },
--  --tex some-number entries directly in module root --Results from CheckFoxTableKeysAccountedFor suggests these are functions
--  [11568137] = <function 5841>,
--  [26595625] = <function 5842>,
--  [26595645] = <function 5843>,
--  [49591366] = <function 5844>,
--  [62144975] = <function 5845>,
--  ...
--these modules usually (always?) still have a [-285212671] / enum table but it will be empty {}

--some enum tables have plain text key instead of number/hash
-- BuddyType = <13>{
--    [-285212672] = 0,
--    [-285212671] = {
--      BATTLE_GEAR = <function 128>,
--      DISABLE = <function 129>,
--      DOG = <function 130>,
--      HORSE = <function 131>,
--      NONE = <function 132>,
--      QUIET = <function 133>,
--      WALKER_GEAR = <function 134>
--    },
--    __index = <function 135>,
--    __newindex = <function 136>,
--    <metatable> = <table 13>
--  },

--for (script)var entries
--[-285212666] is array size/count
--[-285212665] is (indexed from 0) array

--REF
--customizedWeaponSlotIndex = <396>{
--  [-285212666] = 3,
--  [-285212665] = <userdata 43>,
local this={}

this.debugModule=true

this.doTearDown=false--tex run in PostAllModulesLoad, NOTE this wont catch everything, so run manually in ACC via foxTearDownMenu > DoTearDown when at least in ACC 

this.writeDebugOutput=true--tex write stuff for debugging the process/seeing if the process is missing out things (written to <dumpDir>/debugDump)
this.buildFromScratch=false--tex whether to build IHGenModuleReferences from scratch by scraping lua files in luaPath
this.dumpDir=[[C:\Projects\MGS\MockFox-TearDownDump\tpp\]]--tex output folder
--also outputs to:
--<dumpDir>/varsDump--DumpRuntimeVars - intended as readable snapshot of vars (shifts arrays from 0 based to 1)
--<dumpDir>/varsAsLib--DumpRuntimeVars - for use as vscode lua extension lib (keeps 0 based as original usage, declares itself as global module)
--<dumpDir>/globalsDump
--<dumpDir>/globalsDump/tables
--<dumpDir>/mockModules
--<dumpDir>/debugDump
--<dumpDit>/misc
--(you need to create the sub folders)
--input
this.luaPath=[[E:\GameData\mgs\filetype-crush\lua\]]--tex unmodded lua, all in same folder, for IHGenModuleReferences buildFromScratch
local mockFoxPath=[[d:\github\MockFox\MockFoxLua\]]
this.classesPath=mockFoxPath..[[info\LuaClasses[sais ida dump]_sorted.txt]]
this.exeCreateModulesLogPath=mockFoxPath..[[log_createmodule.txt]]
--this.exeModulesPath=[[C:\Games\Steam\steamapps\common\MGS_TPP\log_createmodule.txt]]--tex DEBUGNOW VERIFY: cant open/GetLines when running from mgsv because log file still open by ihhook?

--tex fox table shiz, see NOTE above
this.unknownId=-285212672
this.foxTableId=-285212671--tex key contains an array of id entries--Results from CheckFoxTableKeysAccountedFor suggests this is the enum table TODO: then renames it foxEnumId?

this.varArrayCountId=-285212666
this.varTableId=-285212665

function this.PostAllModulesLoad()
  InfCore.Log("IHTearDown.PostAllModulesLoad")

  if this.doTearDown then
    if vars.missionCode>5 then
      this.DoTearDown()
    end
  end
end

--NOTE: this should be run at least in ACC
--Some of the modules and some of the keys aren't up and running during start/start2nd.lua but are by ACC.
--So just relying on the initial PostAllModulesLoad wont cut it
function this.GenerateMockModules(options)
  InfCore.Log"GenerateMockModules"
  --tex get _G/globals organised by type, filtering out IH or lua api stuff (listed in IHGenKnownModuleNames)
  --NOTE: since this grab the actual tables from _G so in theory you can check it later down the line with foxtable shiz, 
  --unless the k/t has some weird meta setup i haven't considered
  local globalsByType=this.GetGlobalsByType(IHGenKnownModuleNames)
  if this.debugModule then
    InfCore.PrintInspect(globalsByType,"globalsByType")
  end
  InfCore.PrintInspect(globalsByType.other,"globalsByType.other")--tex TODO: check this out

  --tex build up references to potential modules from various sources>
  --tex process log file created by ihhook/exe hooking of module creation functions into a more useful table
  local exeModuleRefs,exeModuleRefsEntryOrder=this.BuildModuleRefsFromExeLog(this.exeCreateModulesLogPath)--tex TODO dump this
  if this.debugModule then
    InfCore.PrintInspect(exeModuleRefs,"exeModuleRefs")
    InfCore.PrintInspect(exeModuleRefsEntryOrder,"exeModuleRefsEntryOrder")--tex is written during write dumps
  end

  --tex GOTCHA: this may be depreciated if the above BuildModuleRefsFromExeLog covers everything
  --tex building/using module references built by scraping actual lua files, so they can be tested against the unknown foxtabled keys,
  --as well as just seeing if there's any discrepancies with live globals
  --tex NOTE: takes a fair while to run. Run it once, then use the resulting combined table .lua (after copying it to MGS_TPP\mod\modules and loading it) --DEBUGNOW
  --open ih_log.txt in an editor that live refreshes to see progress
  local luaSourceRefs
  if options.buildFromScratch==true then
    --tex scrapes module references from lua files
    --is written to file later in this function
    luaSourceRefs=this.GetModuleReferences(globalsByType.table)
    if this.debugModule then
      InfCore.PrintInspect(luaSourceRefs,"moduleReferences")--tex is written during write dumps
    end
  else
    --tex use module previously built/saved from above process
    luaSourceRefs=IHGenModuleReferences--ASSUMPTION output of above has been loaded as a module
    if this.debugModule then
      InfCore.PrintInspect(luaSourceRefs,"moduleReferences")--tex not written at end (because it is already itself)
    end
  end
  --tex build up references to potential modules from various sources<

  --tex build individual mock modules for each of the above reference modules, just so we can compare how complete the references are>
  
  --tex Build initial mock modules from looking at the plain text keys in the live/runtime global modules
  --as mentioned in the notes in this files header above, this misses a lot of stuff obscured by whatever the foxtable process is 
  local mockModules=this.BuildMockModulesFromLive(globalsByType.table)
  if this.debugModule then
    InfCore.PrintInspect(mockModules,"mockModules step1 live plaintext")--tex is written during write dumps (after multiple merges)
  end

  local mockModulesFromExeRefs,exeRefsNotFoundInLive,liveNotFoundInExeRefs=this.BuildMockModulesFromReferences(globalsByType.table,exeModuleRefs)
  if this.debugModule then
    InfCore.PrintInspect(mockModulesFromExeRefs,"mockModulesFromExe")
    --tex is written out later
    InfCore.PrintInspect(exeRefsNotFoundInLive,"exeRefsNotFoundInLive")--tex is written during write dumps
    InfCore.PrintInspect(liveNotFoundInExeRefs,"liveNotFoundInExeRefs")--tex is written during write dumps
  end

  local mockModulesFromLuaRefs,luaRefsNotFoundInLive,liveNotFoundInLuaRefs=this.BuildMockModulesFromReferences(globalsByType.table,luaSourceRefs)
  if this.debugModule then
    InfCore.PrintInspect(mockModulesFromLuaRefs,"mockModulesFromRefs")
     --tex is written out later in this function
    InfCore.PrintInspect(luaRefsNotFoundInLive,"luaRefsNotFoundInLive")--tex is written during write dumps
    InfCore.PrintInspect(liveNotFoundInLuaRefs,"liveNotFoundInLuaRefs")--tex is written during write dumps
  end
  --tex build individual mock modules<

  --tex merge different mock modules>
  --at this point, for debugging purposes, there's 3 different mockModules tables built, 
  --so merge them to get the (hopefully) complete mockModules
  InfCore.Log("combine mockModulesFromExe to mockModules")
  for moduleName,module in pairs(mockModulesFromExeRefs) do
    for k,v in pairs(module)do
      if not mockModules[moduleName] then
        InfCore.Log(moduleName.." could not find module in mockmodules")
      elseif not mockModules[moduleName][k] then
        mockModules[moduleName][k]=v
      end
    end
  end
  if this.debugModule then
    InfCore.PrintInspect(mockModules,"mockModules step2 merge with mockModulesFromExeRefs")
  end

  InfCore.Log("combine mockModulesFromRefs to mockModules")
  for moduleName,module in pairs(mockModulesFromLuaRefs) do
    for k,v in pairs(module)do
      if not mockModules[moduleName] then
        InfCore.Log(moduleName.." could not find module in mockmodules")
      elseif not mockModules[moduleName][k] then
        mockModules[moduleName][k]=v
      end
    end
  end
  if this.debugModule then
    --tex is written out later in this function
    InfCore.PrintInspect(mockModules,"mockModules step3 merge with mockModulesFromLuaRefs - final all combined")
  end
  --tex merge different mock modules<
  --tex mock modules built at this point (but not yet written to files)
  
  --tex stuff for debugging the process/seeing if the process is missing out things>
  local missedModules={}
  local liveModuleKeysVsMock
  if this.writeDebugOutput then
    for name,module in pairs(globalsByType.table)do
      if not mockModules[name] then
        missedModules[name]=true
      end
    end
    if this.debugModule then
      InfCore.PrintInspect(missedModules,"missedModules")--tex is written during write dumps
    end
    
    liveModuleKeysVsMock=this.CheckFoxTableKeysAccountedFor(globalsByType.table,mockModules)
    if this.debugModule then
      InfCore.PrintInspect(liveModuleKeysVsMock,"liveModuleKeysVsMock")
    end
  end-- if writeDebugOutput
  --stuff for debugging<


  --tex write dumps
  local header={
    [[--ModulesDump.lua]],
    [[--GENERATED by IHTearDown]],
    [[--Straight Inspect dump of mgstpp global tables (globalsByType.table, so filtering out some stuff)]],
  }
  local outDir=this.dumpDir..[[globalsDump\]]
  this.DumpToFiles(outDir..[[tables\]],globalsByType.table)
  
  for tableName,globalTable in pairs(globalsByType)do
    local fileName="GlobalsDump-"..tableName..".lua"
    local header={
      [[--]]..fileName,
      [[--GENERATED by IHTearDown]],
      [[--Straight Inspect dump of mgstpp globals of type]],
    }
    this.WriteTable(outDir..fileName,table.concat(header,"\r\n"),globalTable)
  end--for globalsByType

  if luaSourceRefs~=IHGenModuleReferences then--tex no point dumping a dump
    local header={
      [[--IHGenModuleReferences.lua]],
      [[--GENERATED by IHTearDown.GenerateMockModules > GetModuleReferences]],
      [[--is scrape of references to modules in .lua files]],
      [[--used as input for BuildMockModulesFromReferences]],
    }
  --tex now that were using module creation logging, IHGenModuleReferences is less important
  --local outDir=this.dumpDir..[[moduleReference\]]
  --this.DumpToFiles(outDir,moduleReferences)
  this.WriteTable(this.dumpDir.."IHGenModuleReferences.lua",table.concat(header,"\r\n"),luaSourceRefs)
  end

  local header={
    [[--IHGenMockModules.lua]],
    [[--GENERATED by IHTearDown from running mgs combined with scrapes of .lua files for further module references (due to internal mgs_tpp modules indexing crud, see NOTE above GenerateMockModules)]],
    [[--ultimate output of IHTearDown.GenerateMockModules]],
    [[--also see this.dumpDir\mockModules\ for the same output as a file per module]]
  }
  local outDir=this.dumpDir..[[mockModules\]]
  --this.DumpToFiles(outDir,mockModules)--DEBUGNOW OLD CULL
  local setThisAsGlobal=true--DEBUGNOW
  this.WriteMockModules(outDir,mockModules,exeModuleRefs,exeModuleRefsEntryOrder,setThisAsGlobal)
  this.WriteTable(this.dumpDir.."IHGenMockModules.lua",table.concat(header,"\r\n"),mockModules)
  
  --tex write GenerateMockModules process debugging stuff>
  local header={
    [[--IHExeModulesEntryOrder.lua]],
    [[--GENERATED by IHTearDown BuildModuleRefsFromExeLog]],
    [[--order of modules according to hooking/logging the exe module creation functions]],
    [[--just for debugging GenerateMockModules process]]
  }
  this.WriteTable(this.dumpDir.."IHExeModulesEntryOrder.lua",table.concat(header,"\r\n"),exeModuleRefsEntryOrder)
  
  if this.writeDebugOutput then
    local outDir=this.dumpDir..[[debugDump\]]

    local header={}
    this.WriteTable(outDir.."exeModuleRefs.lua",table.concat(header,"\r\n"),exeModuleRefs)

    local header={
      [[--exeRefsNotFoundInLive.lua]],
      [[--GENERATED by IHTearDown BuildMockModulesFromReferences]],
      [[--references from exeModules (from BuildModuleRefsFromExeLog) that werent found in live session]],
      [[--just for debugging GenerateMockModules process]]
    }
    this.WriteTable(outDir.."exeRefsNotFoundInLive.lua",table.concat(header,"\r\n"),exeRefsNotFoundInLive)
  
    --tex mostly the same as below but whatev
    local header={
      [[--liveNotFoundInExeRefs.lua]],
      [[--GENERATED by IHTearDown BuildMockModulesFromReferences]],
      [[--references from live session that werent found in exeModules]],
      [[--just for debugging GenerateMockModules process]]
    }
    this.WriteTable(outDir.."liveNotFoundInExeRefs.lua",table.concat(header,"\r\n"),liveNotFoundInExeRefs)
  
    local header={
      [[--luaRefsNotFoundInLive.lua]],
      [[--GENERATED by IHTearDown BuildMockModulesFromReferences]],
      [[--references from IHGenModuleReferences (which is from scrapes of the games lua files) that werent found in live session]],
      [[--just for debugging GenerateMockModules process, in this case useful for tracking down typos and seeing where BuildMockModulesFromReferences makes mistakes]]
    }
    this.WriteTable(outDir.."luaRefsNotFoundInLive.lua",table.concat(header,"\r\n"),luaRefsNotFoundInLive)
  
    --tex mostly the same as below but whatev
    local header={
      [[--liveNotFoundInLuaRefs.lua]],
      [[--GENERATED by IHTearDown BuildMockModulesFromReferences]],
      [[--references from live session that werent found in IHGenModuleReferences]],
      [[--just for debugging GenerateMockModules process]]
    }
    this.WriteTable(outDir.."liveNotFoundInLuaRefs.lua",table.concat(header,"\r\n"),liveNotFoundInLuaRefs)
  
    local header={
      [[--IHMissedModules.lua]],
      [[--GENERATED by IHTearDown]],
      [[--global module names that werent in generated mockmodules]],
    }
    this.WriteTable(outDir.."IHMissedModules.lua",table.concat(header,"\r\n"),missedModules)
    
     local header={
      [[--IHLiveModuleKeysVsMock.lua]],
      [[--GENERATED by IHTearDown CheckFoxTableKeysAccountedFor]],
      [[--comparing live globals fox table keys vs generated mock modules]],
      [[--lists all live modules,keys and whether a mock module entry matches it, or its NOT_FOUND]],
      [[--TODO: for some reason cant match enums in this way]],
      [[--just for debugging GenerateMockModules process to see if module creation logging vs fox tables is missing stuff (or that CheckFoxTableKeysAccountedFor isnt actually complete)]]
    }
    this.WriteTable(outDir.."IHLiveModuleKeysVsMock.lua",table.concat(header,"\r\n"),liveModuleKeysVsMock)
  end--if this.writeDebugOutput 
  --write GenerateMockModules process debugging stuff<
end--GenerateMockModules

--TODO: dump raw _G
function this.DumpRuntimeVars()
  InfCore.Log("IHTearDown.DumpRunTimeVars")
  --tex runtime dumps>
  if vars.missionCode<=5 then
    InfCore.Log("vars.missionCode<=5, will not output dump files")
    return
  end
  if isMockFox then
    InfCore.Log("isMockFox, will not output dump files")
    return
  end

  --snapshot
  local indexBy1=true
  local varsTables={
    vars=this.DumpVars(vars,indexBy1),
    cvars=this.DumpVars(cvars,indexBy1),
    svars=this.DumpSaveVars(svars,indexBy1),
    gvars=this.DumpSaveVars(gvars,indexBy1),
    --tex these are plain tables as they arent saved or anything, mgsv just clears it on mission change (TODO: when exactly?)
    --GOTCHA: straight inspect, so no indexby1 (but most of mvars is used as normal lua by 1 arrays anyway?)
    mvars=mvars,
  }

  for varsName,varsTable in pairs(varsTables)do
    local header={}
    table.insert(header,"--"..varsName..".lua")
    table.insert(header,[[--GENERATED by IHTearDown.DumpVars]])
    table.insert(header,[[--readable snapshot style: runtime vars arrays are indexed from 0, but this output is indexed from 1 lua style]])
    table.insert(header,[[--dump of vars during missionCode:]]..vars.missionCode)
    local outPath=this.dumpDir.."\\varsDump\\"..varsName..".lua"
    this.WriteTable(outPath,table.concat(header,"\r\n"),varsTable)
  end--for varsTable
  --< snapshot

  --tex as lib
  local indexBy1=false--tex is the default of the dump functions anyway
  local varsTables={
    vars=this.DumpVars(vars),
    cvars=this.DumpVars(cvars),
    svars=this.DumpSaveVars(svars),
    gvars=this.DumpSaveVars(gvars),
    mvars=mvars,--tex these are plain tables as they arent saved or anything, mgsv just clears it on mission change (TODO: when exactly?)
  }

  for varsName,varsTable in pairs(varsTables)do
    local header={}
    table.insert(header,"--"..varsName..".lua")
    table.insert(header,[[--GENERATED by IHTearDown.DumpVars]])
    table.insert(header,[[--vscode lua extension lib style: runtime vars arrays are indexed from 0, this module declares itself as global (at end)]])
    table.insert(header,[[--dump of vars during missionCode:]]..vars.missionCode)
    local outPath=this.dumpDir.."\\varsAsLib\\"..varsName..".lua"
    local setThisAsGlobal=varsName--KLUDGE
    this.WriteTable(outPath,table.concat(header,"\r\n"),varsTable,setThisAsGlobal)
  end--for varsTable
  --< as lib  
end--DumpRuntimeVars

function this.DumpRuntimeVarsDebug()
  --DEBUGNOW compare svars and gvars vs what entries are defined lua side to see if we're missing something/or anything is added exe side
  --GOTCHA: these will include IH s/gvars?
  --DEBUGNOW this stuff really needs to be run in-mission, via a reloadscripts or on command
  local svarsDeclaredTable=nil
  if TppMain.allSvars==nil then
    InfCore.Log("WARNING: RunTimeDumps TppMain.allSvars==nil")
  else
    svarsDeclaredTable=this.DumpVarsDeclareTable(TppMain.allSvars)
  end
  local gvarsDeclaredTable=nil
  if TppGVars==nil then--tex modules are up and running / postallmodules is before tppgvars is loaded
    InfCore.Log("WARNING: RunTimeDumps TppGVars==nil")
  else
    if TppGVars.DeclareGVarsTable==nil then
      InfCore.Log("WARNING: RunTimeDumps TppGVars.DeclareGVarsTable==nil")
    else
      gvarsDeclaredTable=this.DumpVarsDeclareTable(TppGVars.DeclareGVarsTable)
    end
  end

  local svarsDeclaredName="svarsDeclaredTable.lua"
  local header={
    [[--]]..svarsDeclaredName,
    [[--GENERATED by IHTearDown.DumpVarsDeclareTable]],
    [[--dump of vars during missionCode:]]..vars.missionCode,
  }
  this.WriteTable(this.dumpDir.."\\debugDump\\"..svarsDeclaredName,table.concat(header,"\r\n"),svarsDeclaredTable)

  local gvarsDeclaredName="gvarsDeclaredTable.lua"
  local header={
    [[--]]..gvarsDeclaredName,
    [[--GENERATED by IHTearDown.DumpVarsDeclareTable]],
    [[--dump of vars during missionCode:]]..vars.missionCode,
  }
  this.WriteTable(this.dumpDir.."\\debugDump\\"..gvarsDeclaredName,table.concat(header,"\r\n"),gvarsDeclaredTable)
end--DumpRuntimeVarsDebug

function this.OtherRunTimeAnalyze()
  --tex other peoples mgsv data to my analysis
  local nonLiveClasses=this.FindNonLiveClasses(this.classesPath)
  InfCore.PrintInspect(nonLiveClasses,"nonLiveClasses")--tex TODO force newlined --tex is written during write dumps

  local entityClassDictionary=this.DumpEntityClassDictionary()

  --tex write other peoples mgsv data > my analysis dumps>
  local header={
    [[--IHGenUnfoundLiveClassesIda.lua]],
    [[--GENERATED by IHTearDown BuildMockModulesFromReferences]],
    [[--references from LuaClasses[ida dump] that werent in live session ]],
  }
  this.WriteTable(this.dumpDir.."\\misc\\".."IHGenUnfoundLiveClassesIda.lua",table.concat(header,"\r\n"),nonLiveClasses)


  local header={
    [[--IHGenEntityClassDictionary.lua]],
    [[--GENERATED by IHTearDown DumpEntityClassDictionary]],
    [[--dump of EntityClassDictionary.GetCategoryList, GetClassNameList]],
  }
  this.WriteTable(this.dumpDir.."\\misc\\".."IHGenEntityClassDictionary.lua",table.concat(header,"\r\n"),entityClassDictionary)
  --write other data stuff
end--OtherRunTimeAnalyze

--tex breaks down global variables by type
--mostly to seperate out fox modules
--IN/SIDE:
--IHGenKnownModuleNames - IHGenKnownModuleNames.lua --tex lists of known module names (mostly just from filenames)
--_G
--OUT: globalsByType={
--  function={--mostly lua api functions to ignore},
--  other = {
--    NULL = <userdata 1>,
--    _U = true
--  },
--  string = {
--    _VERSION = "Lua 5.1"
--  },
--  table = {
--    ActionIcon = <1>{
--      [-285212672] = 4,
--      [-285212671] = {
--        [5310743] = <function 30>,
--        [14142738] = <function 31>,
--      ...
--      },
--      __index = <function 41>,
--      __newindex = <function 42>,
--      <metatable> = <table 1>
--    },
--    ... other modules, what we're actually insterested in
--}
function this.GetGlobalsByType(ModuleNames)
  --tex names of tables in KnownModuleNames to skip
  local skipModuleTableNames={
    "ihInternal",
    "ihExternal",
    "ihModelInfo",
    "tppInternal",
    "ssdinternal",
    "luaInternal",
  }

  local skipModuleNames={
    _G=true,
    package=true,
    this=true,
  }

  local globalsByType={
    ["table"]={},
    ["function"]={},
    ["string"]={},
    other={},
  }
  local globalFunctions={}
  local globalTables={}
  local globalOther={}
  for k,v in pairs(_G)do
    local addEntry=true
    for i,moduleNameTable in ipairs(skipModuleTableNames)do
      if ModuleNames[moduleNameTable] and ModuleNames[moduleNameTable][k] then
        addEntry=false
        break
      end
    end

    if skipModuleNames[k] then
      addEntry=false
    end

    --tex theres some strange edge cases where theres a provided lua, but also an exe internal module of that name
    if ModuleNames.exeInternal[k] then
      addEntry=true
    end

    if addEntry then
      local globalsOfType=globalsByType[type(v)]
      globalsOfType=globalsOfType or globalsByType.other
      globalsOfType[k]=v
    end
  end
  return globalsByType
end--GetGlobalsByType

--UNUSED CULL?
--tex breaks down modules keys by type
function this.GetModuleKeysByType(modules)
  InfCore.Log("GetModuleKeysByType")
  local breakDown={}
  for moduleName,module in pairs(modules)do
    local tableInfo={
      stringKeys={},
      numberKeys={},
    }
    local function GetTableKeys(checkTable,tableInfo)
      for key,value in pairs(checkTable)do
        if type(key)=="string" then
          table.insert(tableInfo.stringKeys,key)
        elseif type(key)=="number" then
          table.insert(tableInfo.numberKeys,key)
          if type(value)=="table" then
            GetTableKeys(value)
          end
        end
      end
    end

    GetTableKeys(module,tableInfo)

    if #tableInfo.numberKeys>0 then
      breakDown[moduleName]=tableInfo
    end
  end
end--GetModuleKeysByType

--tex scrapes module references from lua files
--DEBUGNOW REWORK
--just do a straight search for . : and build up it's own module names, that way it can also catch stuff like CyprRailActionDataSet that only calls via a variable
--break lines on ")", "}", "]", "=", ","??
--," " -- would be nice, but would miss cases such as 'blah.Functionname ('
--for brokenLines
--refpos = findfirst '.'
--type=normalref
--refpos = findfirst ':'
--type=selfref

--DEBUGNOW DOES delims/split remove the delim chars from the lines??

--from refpos left/decement/toward start of line
--objstartPos=find/breakup string by anything not alphanumeric or start of line
--what if is ..? -- that would be objstartPos==refpos?
--objectName = refPos to objstartPos

--from refPos right/increment/toward end of line
--memberEndPos =find/break on alphanumeric or end of line
--" ",???
--what if 'blah.Functionname (' or 'blah.Functionname<tab>(' ??
--In/SIDE: modules: globablsByType.table - filtered _G globals of table/modules
--lua files in this.luaPath
function this.GetModuleReferences(modules)
  InfCore.Log("GetModuleReferences")

  --tex get paths of lua files ASSUMPTION: all lua files in one folder/no subfolders
  local outName="luaFileList.txt"

  local startTime=os.clock()

  local cmd=[[dir /s /b "]]..this.luaPath..[[*.lua" > "]]..this.luaPath..outName..[["]]
  InfCore.Log(cmd)
  os.execute(cmd)

  local luaFilePaths=InfCore.GetLines(this.luaPath..outName)
  --InfCore.PrintInspect(luaFilePaths,"luaFilePaths")--DEBUG

  local numFiles=#luaFilePaths

  local refs={}
  for i,filePath in ipairs(luaFilePaths)do
    InfCore.Log("["..i.."//"..numFiles.."] "..filePath)--DEBUG
    local lines=InfCore.GetLines(filePath)
    for i,fileLine in ipairs(lines)do
      for moduleName,moduleInfo in pairs(modules)do
        local fileLine=fileLine

        --tex break up lines
        local brokenLines={}
        local delim = {
          ",", " ", "\n", "%]", "%)", "}", "\t",
          "%+","-",">","<","=","/","%*","~","%%",
          "'","\"","{","%(","%[",
        }
        local pattern = "[^"..table.concat(delim).."]+"
        for w in fileLine:gmatch(pattern) do
          --InfCore.Log(w)
          table.insert(brokenLines,w)
        end

        --InfCore.Log("looking for "..moduleName)--DEBUGNOW
        for i,line in ipairs(brokenLines)do
          local findIndex,findEndIndex=string.find(line,moduleName)
          while(findIndex~=nil)do
            local findEndIndex=findIndex+string.len(moduleName)
            line=string.sub(line,findEndIndex)
            local nextChar=string.sub(line,1,1)
            --InfCore.Log("find: "..moduleName.. " line:"..line)--DEBUGNOW
            --InfCore.Log("find: "..moduleName.. " nextChar:"..nextChar)--DEBUGNOW
            if nextChar=="." or nextChar==":" then
              --DEBUGNOW TODO: handle + - < > == number (can + be concat string too?)

              --              local keyType
              --              if line:find("%(") then
              --                keyType="function"
              --                key=key:sub(1,key:len()-1)
              --              elseif line:find("%[") then
              --                keyType="table"
              --                key=key:sub(1,key:len()-1)
              --             elseif line:find("%:") then--DEBUGNOW
              --                --keyType=""--tex most likely a comment
              --                key=key:sub(1,key:len()-1)
              --              elseif line:find("=") then
              --                if line:find("={") then
              --                  keyType="table"
              --                elseif line:find("='") then
              --                  keyType="string"
              --                elseif line:find("=\"") then
              --                  keyType="string"
              --                end
              --                --tex =something is unknown, could be any type being assigned to it
              --                local endIndex=line:find("=")
              --                key=key:sub(1,endIndex-2)
              --              end

              local key=string.sub(line,2)--tex strip leading .

              local keyEndIndex=string.find(key,"[%.:]")
              if keyEndIndex then
                key=string.sub(key,1,keyEndIndex-1)
              end

              local nextChar=string.sub(key,1,1)
              if findIndex==1 then--DEBUGNOW
                if key~="" and type(nextChar)~="number"then
                  refs[moduleName]=refs[moduleName]or{}
                  refs[moduleName][key]=true
              end
              end
            end

            findIndex=string.find(line,moduleName)
            --InfCore.Log(findIndex)--DEBUGNOW
          end
        end
      end
    end
  end

  InfCore.Log(string.format("GetModuleReferences completed in: %.2f", os.clock() - startTime))

  return refs
end--GetModuleReferences

--tex Outputs the modules with plain text keys, not the foxtabled keys (see NOTE above GenerateMockModules)
--IN: modules: globalsByType.table (_G entries of type table)
--OUT: mockModules={
--  Application = {
--    AddGame = "<function>",
--    GetGame = "<function>",
--    GetGames = "<function>",
--    GetInstance = "<function>",
--    GetMainGame = "<function>",
--    GetScene = "<function>",
--    RemoveGame = "<function>",
--    SetMainGame = "<function>",
--    __call = "<function>",
--    __index = "<function>",
--    __newindex = "<function>",
--    _className = "Application"
--  },
--  ...--other modules
--}
function this.BuildMockModulesFromLive(liveModules)
  local mockModules={}

  local ignoreModules={
    vars=true,
    cvars=true,
    gvars=true,
    svars=true,
    mvars=true,
  }

  local ignoreKeys={
    __call=true,
    __newindex=true,
    __index=true,
  }
  
  for moduleName,module in pairs(liveModules)do
    if not ignoreModules[moduleName] then
      local mockModule={}
      mockModules[moduleName]=mockModule
      if type(module)=="table"then
        for k,v in pairs(module)do
          --NOTE only string keys to skip userdata/indexified modules (type(k)== number) keys, see NOTE above GenerateMockModules
          if type(k)=="string" then
            if not ignoreKeys[k] then
              if type(v)=="function" then
                mockModule[k]="<function>"
              elseif type(v)=="table" then
                mockModule[k]=[["<table> TODO: BuildMockModules this is probably a nested foxtable"]]--tex actually not likely in plaintext, more likely on foxtables itself (see comments on TppCommand.Weather)
              elseif type(v)=="userdata" then
                mockModule[k]="<userdata>"--ALT "<"..tostring(v)..">"--tex gives "<userdata: ADDRESS>" where address is different each session, so not the best since it will create a diff every capture
              else
                mockModule[k]=v
              end
            end
          end--if type(k)
        end--for module
      end--if module is a table
    end--ignoremodules
  end--for modules
  return mockModules
end--BuildMockModules

--IN: exeLogPath: ihhook log_createmodule.txt
--which is logged from hooks UnkNameModule, AddCFuncToModule2, AddEnumToModule2 which are called by RegisterLuaModule<module name> functions
--REF log_createmodule.txt
--...
--module: ScriptBlock
--enum: SCRIPT_BLOCK_STATE_EMPTY=0
--enum: SCRIPT_BLOCK_STATE_PROCESSING=1
--enum: SCRIPT_BLOCK_STATE_INACTIVE=2
--enum: SCRIPT_BLOCK_STATE_ACTIVE=3
--enum: TRANSITION_LOADED=0
--enum: TRANSITION_ACTIVATED=1
--enum: TRANSITION_DEACTIVATED=2
--enum: TRANSITION_EMPTIED=3
--func: GetScriptBlockId
--func: GetCurrentScriptBlockId
--func: Load
--func: Reload
--func: Activate
--func: Deactivate
--func: IsProcessing
--func: GetScriptBlockState
--func: UpdateScriptsInScriptBlocks
--func: ExecuteInScriptBlocks
--...
--OUT: modules={
--  ...
--  ScriptBlock = {
--    Activate = "function",
--    Deactivate = "function",
--    ExecuteInScriptBlocks = "function",
--    GetCurrentScriptBlockId = "function",
--    GetScriptBlockId = "function",
--    GetScriptBlockState = "function",
--    IsProcessing = "function",
--    Load = "function",
--    Reload = "function",
--    SCRIPT_BLOCK_STATE_ACTIVE = 3,
--    SCRIPT_BLOCK_STATE_EMPTY = 0,
--    SCRIPT_BLOCK_STATE_INACTIVE = 2,
--    SCRIPT_BLOCK_STATE_PROCESSING = 1,
--    TRANSITION_ACTIVATED = 1,
--    TRANSITION_DEACTIVATED = 2,
--    TRANSITION_EMPTIED = 3,
--    TRANSITION_LOADED = 0,
--    UpdateScriptsInScriptBlocks = "function"
--  },
--  ... other modules

--DEBUGNOW go through these and export and tag
--go through all these and see if theres any lower functions that are being used instead of the higher
--1.0.15.3 addrs
--module    - 0x14c1f9150 - foxlua::NewModule         - from UnkNameModule 
--submodule - 0x14c1f9b40 - foxlua::NewSubModule      - sub module of previous module 
--function  - 0x14c1f7400 - foxlua::AddCFuncToModule  - main function used
--function2 - 0x14c1f87c0 - foxlua::AddCFuncToModule2 - module "StringId" "IsEqual", "IsEqual32"
--function3 - 0x14c1f4dc0 - foxlua::AddCFuncToModule3 - sub of 0x14c1f7400 AddCFuncToModule and some other calls to it?
--function4 - 0x143143000 - RegisterLib               - calls lua api luaL_register, so these should be plainly inspectable from lua  - TODO: hook and log
--enum      - 0x14c1f76c0 - foxlua::AddEnumToModule   - main function used
--enum2     - 0x14c1f38e0 - foxlua::AddEnumToModule2  - sub call of 0x14c1f76c0 AddEnumToModule, but FUN_14bd1cf39 calls it? code is a mess all around there.
--enum3     - 0x14c1f79b0 - foxlua::AddEnumToModule3  - module "StringId" "IsEqual", "IsEqual32"
--enum4     - 0x14c1f3b70 - foxlua::AddEnumToModule4  - 

--var       - 0x14c1f9e20 - RegisterVar        - TODO log - vars,cvar , and some other modules?
--varArray  - 0x14c1f4ec0 - RegisterVarArray -- TODO LOG - vars and ?
--?? any others?
--DeclareEntityClass - 0x14317f430 - DeclareEntityClass -- not lua module creation, but interesting to log

--assume value string "function" = function, number = number, and other string to be enum that couldnt convert to num (havent seen any)
--TODO: may want to gather order of enums added, and seperate different enums in same module
--ie if lastLineType == enum

--GOTCHA: there's a couple of edge cases with the exe dump, as seen in IHGenUnfoundReferencesExe.lua
--    TppCommand = {
--    RegisterClockMessage = true,
--    SetClockTimeScale = true,
--    UnregisterAllClockMessages = true,
--    UnregisterClockMessage = true
--  },
--these functions are actually in a sub table TppCommand.Weather, as seen in FUN_144c1d3b0
--you can see a call to UnkNameModule which is what is actually hooked, dont know why exec flow doesnt pass into it/it doesnt log though
--ditto Vehicle which has sub tables with enums - type, subType, paintType, class etc

function this.BuildModuleRefsFromExeLog(exeLogPath)
  InfCore.Log("BuildModuleRefsFromExeLog")
  local modules={}
  local modulesEntryOrder={}
  local lines=InfCore.GetLines(exeLogPath)
  local lastLineType=""
  local currentModuleName=""
  local currentModule=nil
  local parentModuleName=""
  local parentModule=nil

  local currentModuleOrder=nil
  for i,line in ipairs(lines)do
    local findIndex,findEndIndex=string.find(line,":")
    if findIndex~=nil then
      local lineType=string.sub(line,1,findEndIndex-1)
      local lineInfo=string.sub(line,findEndIndex+1,-1)
      --InfCore.Log(i.." lineType:'"..tostring(lineType).."' lineInfo:'"..lineInfo.."'")
      local keyName=lineInfo
      local strValue=nil
      local findIndex,findEndIndex=string.find(lineInfo,"=")
      if findIndex~=nil then
        keyName=string.sub(lineInfo,1,findEndIndex-1)
        strValue=string.sub(lineInfo,findEndIndex+1,-1)
      end
      if currentModule and currentModule[keyName] then
        InfCore.Log("WARNING: BuildModuleRefsFromExeLog: entry already defined: "..lineType.." "..currentModuleName.."."..keyName)
      end

      --tex KLUDGE WORKAROUND no way of detecting when a submodule ends and entries to parent module continue
      --but theres only one case of this so hardcode it
      --REF
      -- module:Vehicle
      -- ...
      -- module3:observation
      -- ...
      -- enum:PLAYER_STOPS_VEHICLE_BY_BREAKING_WHEELS=8
      -- enum:ALL=15
      --tex this is actually end of submodule observation and continuation of parent module Vehicle
      -- enum:instanceCountMax=60
      -- func:svars
      -- func:SaveCarry
      if currentModuleName and currentModuleName=="observation"then
        if keyName and keyName=="instanceCountMax" then
          currentModuleName=parentModuleName
          currentModule=parentModule
          currentModuleOrder=modulesEntryOrder[currentModuleName]
        end
      end

      if lineType=="module"then
        currentModuleName=keyName
        if modules[currentModuleName] then
          InfCore.Log("WARNING: BuildModuleRefsFromExeLog: module already defined: "..currentModuleName)
        end

        currentModule=modules[currentModuleName] or {}
        modules[currentModuleName]=currentModule
        --tex for module3/submodule
        parentModuleName=currentModuleName
        parentModule=currentModule
        
        currentModuleOrder=modulesEntryOrder[currentModuleName] or {}
        modulesEntryOrder[currentModuleName]=currentModuleOrder
      elseif lineType=="module3" or lineType=="submodule" then--TODO: rename to submodule in logger
        --tex sub module of previous "module"
        local subModuleName=keyName
        if currentModule[subModuleName] then
          InfCore.Log("WARNING: BuildModuleRefsFromExeLog: subModule "..subModuleName.." module already defined on parent module "..currentModuleName)
        end

        --tex there arent nested submodules, only ever submenu(s) of a root paratent menu
        local subModule = parentModule[subModuleName] or {}
        parentModule[subModuleName]=subModule

        local subMenuOrder = modulesEntryOrder[parentModuleName][subModuleName] or {}
        modulesEntryOrder[parentModuleName][subModuleName]=subMenuOrder
        --tex parent module still needs to know
        table.insert(modulesEntryOrder[parentModuleName],keyName)

        currentModuleOrder=subMenuOrder

        currentModuleName=subModuleName
        currentModule=subModule
      elseif lineType=="enum" or lineType=="enum2" or lineType=="enum3"or lineType=="enum4" then
        --InfCore.Log(i.." keyName:'"..tostring(enumName).."' enumValue:'"..enumValue.."'")

        local numValue=tonumber(strValue)
        if numValue==nil then
          InfCore.Log("WARNING: BuildModuleRefsFromExeLog: could not convert "..lineType.." "..currentModuleName.."."..keyName.."="..strValue.." to a number")
          currentModule[keyName]="NON_NUMBER-"..strValue
        else
          currentModule[keyName]=lineType
        end
        
        table.insert(currentModuleOrder,keyName)
      elseif lineType=="func" or lineType=="function"or lineType=="function2" or lineType=="function3" then--tex TODO: change logging to "function"
        currentModule[lineInfo]="function"
        
        table.insert(currentModuleOrder,keyName)
      elseif lineType=="var"or lineType=="var1" or lineType=="var2" or lineType=="var3" or lineType=="var4" then
        currentModule[lineInfo]="var"
        
        table.insert(currentModuleOrder,keyName)
      elseif lineType=="varArray" then
        --tex DEBUGNOW do i need to log size, or can I pull that? 
        currentModule[lineInfo]="varArray"
        
        table.insert(currentModuleOrder,keyName)
      end--if lineType==

      lastLineType=lineType
    end--if ':'
  end--for lines
  return modules,modulesEntryOrder
end--BuildModuleRefsFromExeLog
--BuildMockModulesFromReferences: Creates validated mock modules by testing mock modules generated by different means (lua scrape, or logging exe calls to the module creation funcs) against live (running game) modules 
--IN: liveModules: globalsByType.table / actual _G/globals from running game
--moduleReferences: IHGenModuleReferences - module/function/enum references scraped from the games lua files, 
--or exeCreateModulesLogModules: built from logging the module creation functions
--REF moduleReferences={
--  ...
--  ScriptBlock = {
--    Activate = true,
--    Deactivate = true,
--    GetCurrentScriptBlockId = true,
--    GetScriptBlockId = true,
--    GetScriptBlockState = true,
--    Load = true,
--    SCRIPT_BLOCK_ID_INVALID = true,
--    SCRIPT_BLOCK_STATE_ACTIVE = true,
--    SCRIPT_BLOCK_STATE_EMPTY = true,
--    SCRIPT_BLOCK_STATE_INACTIVE = true,
--    SCRIPT_BLOCK_STATE_PROCESSING = true,
--    TRANSITION_ACTIVATED = true,
--    TRANSITION_DEACTIVATED = true,
--    UpdateScriptsInScriptBlocks = true
--  },
--  ...--other module
--}
--or see OUT of BuildModuleRefsFromExeLog which gives values as "function" or enum 
--OUT: mockModules
--noLiveFound: moduleReferences not found in liveModules
--noReferenceFound: liveModules not found in moduleReferences
--TODO: subtable handling for noLiveFound, noReferenceFound
function this.BuildMockModulesFromReferences(liveModules,moduleReferences)
  InfCore.Log("BuildMockModulesFromReferences")
  local mockModules={}

  local ignoreModules={
    vars=true,
    cvars=true,
    gvars=true,
    svars=true,
    mvars=true,
  }

  local ignoreKeys={
    __call=true,
    __index=true,
    __newindex=true,
    -- _className=true,
    [this.foxTableId]=true,
    [this.unknownId]=true,
  }
  
  --KLUDGE a bunch of the functions are stubbed out/replaced with the same empty function (currently called l_StubbedOut at 0x14024a8e0 in ghidra), using a known one 
  --OFF however it doesnt seem to work, the foxtable setup seems to create a new lua function even if the underlying cfunc is the same
  --local stubbedOutFunc=Fox.Quit
  
  local refsNotFoundInLive={}
  local liveNotFoundInRefs={}

  for referenceModuleName,referenceModule in pairs(moduleReferences)do
    --InfCore.PrintInspect(referenceModule,"referenceModuleName: "..referenceModuleName)
    if not ignoreModules[referenceModuleName] then
      if not liveModules[referenceModuleName] then
        InfCore.Log("Could not find module '"..referenceModuleName.."' from moduleReferences in livemodules")
        refsNotFoundInLive[referenceModuleName]=true
      else
        local liveModule=liveModules[referenceModuleName]
        local mockModule=mockModules[referenceModuleName] or {}
        mockModules[referenceModuleName]=mockModule
        for referenceKey,referenceValue in pairs(referenceModule)do
          if not ignoreKeys[referenceKey] then
            local liveValue=liveModule[referenceKey]
            if liveValue==nil then
              InfCore.Log(referenceModuleName.." could not find live key "..referenceModuleName.."."..tostring(referenceKey))
              refsNotFoundInLive[referenceModuleName]=refsNotFoundInLive[referenceModuleName] or {}
              refsNotFoundInLive[referenceModuleName][referenceKey]=true
            elseif type(referenceKey)=="string" then          
              if type(liveValue)=="function" then
  --                if liveValue==stubbedOutFunc then
  --                  mockModule[k]="<function> (stubbed out)"
  --                else
                  mockModule[referenceKey]="<function>"
  --                end
              elseif type(liveValue)=="table" then
                --tex subtable, only a couple modules have these TppCommand.Weather, Vehicle.a bunch of different subtables
                InfCore.Log("Found subtable: reference: "..referenceModuleName.."."..referenceKey.."="..tostring(referenceValue))
                --tex reference module didn't have enough info on table, just marked its existance with bool/true
                if type(referenceValue)~="table"then
                  mockModule[referenceKey]=[["<table> TODO: BuildMockModulesFromReferences this is probably a nested foxtable"]]--tex  (see comments on TppCommand.Weather)
                else
                  local liveModuleSub={[referenceKey]=liveModule[referenceKey]}--tex BuildMockModulesFromReferences expects {moduleName=module table} for both ref and live
                  local referenceModuleSub={[referenceKey]=referenceModule[referenceKey]}
                  if this.debugModule then
                    InfCore.PrintInspect(referenceModule,"referenceModule")
                    InfCore.PrintInspect(liveModule,"liveModule")
                    InfCore.PrintInspect(referenceModuleSub,"referenceModuleSub")
                    InfCore.PrintInspect(liveModuleSub,"liveModuleSub")
                  end
                  local subTable,noLiveFoundSub,noReferenceFoundSub=this.BuildMockModulesFromReferences(liveModuleSub,referenceModuleSub)
                  mockModule[referenceKey]=subTable[referenceKey]
                end-- type referenceValue
              elseif type(liveValue)=="userdata" then
                mockModule[referenceKey]="<userdata>"
                --mockModule[referenceKey]="<userdata: "..tostring(liveValue)..">"--tex alternative, not great because addr changes each session so bad for diffing 
              else
                if type(referenceValue)~="boolean" and referenceValue~=liveValue then
                  InfCore.Log("WARNING: BuildMockModulesFromReferences "..referenceModuleName.."."..referenceKey.." mismatch referenceValue:"..tostring(referenceValue).." liveValue:"..tostring(liveValue))
                end
                --tex DEBUGNOW decide whether we want to capture live var values (which will only really be a snapshot of when you run GenerateMockModules)
  --                if v=="var" then
  --                   mockModule[k]="<var>"
  --                else
                  mockModule[referenceKey]=liveValue--tex should catch enum values
  --                end
              end-- if type(liveValue)
            else
              InfCore.Log("WARNING: BuildMockModulesFromReferences "..referenceModuleName.."["..tostring(referenceKey).."] unknown key type "..type(k))
            end--if livevalue
          end--if not ignorekey
        end--for referencemodule k,v
      end--if module
    end--if not ignoremodule
  end--for modulereferences

  --tex check noReferenceFound
  for liveModuleName,liveModule in pairs(liveModules)do
    if not moduleReferences[liveModuleName] then
      InfCore.Log("Could not find module '"..liveModuleName.."' from moduleReferences in livemodules")
      liveNotFoundInRefs[liveModuleName]=true
    else
      local referenceModule=moduleReferences[liveModuleName]
      for liveKeyName,liveValue in pairs(liveModule)do
        local referenceValue=referenceModule[liveKeyName]
        if not ignoreKeys[liveKeyName] then
          if referenceValue==nil then
            InfCore.Log(liveModuleName.." could not find reference key "..tostring(liveKeyName))
            liveNotFoundInRefs[liveModuleName]=liveNotFoundInRefs[liveModuleName] or {}
            liveNotFoundInRefs[liveModuleName][liveKeyName]=true
          end
        end--if not ignoreKey
      end--for liveModule
    end--if moduleReference
  end--for livemodules

  return mockModules,refsNotFoundInLive,liveNotFoundInRefs
end--BuildMockModulesFromReferences

function this.CheckFoxTableKeysAccountedFor(liveModules,mockModules)
  InfCore.Log"CheckFoxTableKeysAccountedFor"
  local comparedModules={}

  local ignoreModules={
--    vars=true,
--    cvars=true,
--    gvars=true,
--    svars=true,
--    mvars=true,
  }

  local ignoreKeys={
    [this.unknownId]=true,
    [this.foxTableId]=true,
  }
  
  local knownKeys={
    __call=true,
    __index=true,
    __newindex=true,
    _className=true,  
  }

  for moduleName,liveModule in pairs(liveModules)do
    if type(liveModule)=="table"then
      if not ignoreModules[moduleName] then
        local mockModule=mockModules[moduleName]  
        if not mockModule then
          InfCore.Log("Could not find module "..moduleName.." in mockModules")
          comparedModules[moduleName]="MOCK_MODULE_NOT_FOUND"
        else
          local liveFoxTable=liveModule[this.foxTableId]--MODULE LOCAL
          local isFoxTable=liveFoxTable or false
          --tex KLUDGE check to see if root is foxTable, though as far as I can tell every module that has foxtable entries in root have a foxTableId key, even if the foxTableId array is empty some times
          if not isFoxTable then
            for k,v in pairs(liveModule)do
              if type(k)=="number"then
                isFoxTable=true
                break
              end
            end
          end
          
          if isFoxTable then
            comparedModules[moduleName]={}
 
            this.CheckFoxTableKeys(moduleName,liveModule,liveModule,mockModule,ignoreModules,ignoreKeys,knownKeys,comparedModules[moduleName])--tex check root as foxTable
            if liveFoxTable then
              local foxTableVsMock={}
              comparedModules[moduleName][this.foxTableId]=foxTableVsMock
              this.CheckFoxTableKeys(moduleName,liveModule,liveFoxTable,mockModule,ignoreModules,ignoreKeys,knownKeys,foxTableVsMock)--tex check foxTable key
            end
          end
        end--if mockModule
      end--ignoremodules
    end--if liveModule is a table
  end--for modules
  return comparedModules
end--CheckFoxTableKeysAccountedFor

--OUT/SIDE: liveModuleVsMockModule
function this.CheckFoxTableKeys(moduleName,liveModule,liveTable,mockModule,ignoreModules,ignoreKeys,knownKeys,liveModuleVsMockModule)
  for k,v in pairs(liveTable)do
    if type(k)=="number" then
      if not ignoreKeys[k] then
        local foundMatch=false
        --DEBUGNOW see if this logic still makes sense with all the changes
--        for kk,kv in pairs(knownKeys)do
--          local knownLiveValue=liveTable[kk]
--          if v==knownLiveValue then
--            foundMatch=true
--            liveModuleVsMockModule[k]=kk
--            break
--          end
--        end--for knownKeys
        
        if not foundMatch then
          for mk,mv in pairs(mockModule)do
            --DEBUGNOW this should work for functions and static enums (uhhh DEBUGNOW what about same number values of other keys??), but will fail with vars, solution might be to just set vars value to "var" (see DEBUGNOW in BuildMockModulesFromReferences)
            local mockLiveVal=liveModule[mk]--GOTCHA: have to index into liveModule to get value, foxTableId array (as liveTable) wont get you anything
            --InfCore.Log("CheckFoxTableKeys "..moduleName.."."..mk.."="..tostring(mockLiveVal))
            --tex DEBUGNOW check if nil
            if mockLiveVal==nil then
              InfCore.Log("WARNING: CheckFoxTableKeys "..moduleName.."."..mk.."="..tostring(mockLiveVal))
            elseif type(mockLiveVal)=="function"then
              if v==mockLiveVal then
                foundMatch=true
                liveModuleVsMockModule[k]=mk
                break
              end
            elseif mockLiveVal=="var "then--DEBUGNOW TODO
              foundMatch=true
              liveModuleVsMockModule[k]=mk
              break              
            end
          end--for mockModule
        end--if not foundMatch
        if not foundMatch then
          InfCore.Log("Could not find match for "..moduleName.."["..k.."] in mockModules")
          liveModuleVsMockModule[k]="NOT_FOUND "
        end
      end--if not ignoreKeys
    end--if type(k)
  end--for module
end--CheckFoxTableKeys

function this.GetPlainTextModules(modules)
  local plainTextModules={}

  local ignoreKeys={
    __call=true,
    __newindex=true,
    __index=true,
  }

  for moduleName,module in pairs(modules)do
    for k,v in pairs(module)do
      if type(k)=="string" then
        if not ignoreKeys[k] then
          plainTextModules[moduleName]=true
        end
      end
    end
  end

  return plainTextModules
end
--Dump vars table (and cvars) to a readable table 
--for gvars, svars use DumpSaveVars
--tex GOTCHA: actual runtime vars arrays are indexed indexed from 0, but output here were indexing by 1 so output doesnt look munted, and it can also be used by lua ipairs
function this.DumpVars(inputVars,indexBy1)
  if not inputVars[this.foxTableId] then
    InfCore.Log("WARNING: IHTearDown.DumpVars: inputVars incorrect type? foxTableId not found")
    return
  end

  local varsTable={}

  for k,v in pairs(inputVars[this.foxTableId])do
    varsTable[k]=inputVars[k]
  end

  local skipKeys={
    __index=true,
    __newindex=true,
  }

  local indexStart=indexBy1 and 1 or 0
  local indexShift=indexBy1 and 0 or 1

  for k,foxTable in pairs(inputVars)do
    --tex is actually a foxTable
    if type(foxTable)=="table" then
      if foxTable[this.varArrayCountId] then
        --InfCore.Log("found foxTable "..k)--DEBUGNOW
        if type(k)=="string" then
          if not skipKeys[k] then
            local foxTableArray=foxTable[this.varTableId]
            if foxTableArray then
              varsTable[k]={}
              local arraySize=foxTable[this.varArrayCountId]
              --InfCore.Log("arrayCount="..arrayCount)--DEBUGNOW
              for i=indexStart,arraySize-indexShift do
                varsTable[k][i]=inputVars[k][i]
              end
            end--if foxTableArray
          end--not skipKeys
        end--k==type string
      end--if foxTable[arrayCountIndex]
    end--foxTable==type table
  end--for inputVars

  return varsTable
end--DumpVars

--tex check sais classes name list against _G globals
--IN: classesPath
--_G
--OUT: nonLiveClasses
function this.FindNonLiveClasses(classesPath)
  local nonLiveClasses={}
  local classes=InfCore.GetLines(classesPath)
  for i,className in ipairs(classes)do
    if className~="" then
      if not _G[className] then
        table.insert(nonLiveClasses,className)
      end
    end
  end
  table.sort(nonLiveClasses)
  return nonLiveClasses
end--FindNonLiveClasses

--tex svars,gvars use same layout
--tex GOTCHA: actual runtime vars arrays are indexed from 0, but output here were indexing by 1 so output doesnt look munted, and it can also be used by lua ipairs
function this.DumpSaveVars(inputVars,indexBy1)
  if inputVars==nil then
    InfCore.Log("DumpSaveVars inputVars==nil")
    return
  end

  local varsTable={}

  --tex svars.__as is non array vars
  for k,v in pairs(inputVars.__as)do
    varsTable[k]=v
  end

  --tex svars.__rt is array vars
  --REF
  --  __rt = {
  --      InterrogationNormal = {
  --      __vi = 224,
  --      <metatable> = <table 1>
  --    },
  local indexStart=indexBy1 and 1 or 0
  local indexShift=indexBy1 and 0 or 1
  for k,v in pairs(inputVars.__rt)do
    varsTable[k]={}
    local arraySize=v.__vi--DEBUGNOW not sure if this is right
    for i=indexStart,arraySize-indexShift do
      varsTable[k][i]=inputVars[k][i]
    end
  end

  return varsTable
end--DumpSaveVars

--REF: TppGVars.DeclareGVarsTable ,TppMain.allSvars)
--  {name="str_isAllMissionSRankCleared",type=TppScriptVars.TYPE_BOOL,value=false,save=true,category=TppScriptVars.CATEGORY_GAME_GLOBAL},
--  {name="str_elapsedMissionCount",arraySize=TppDefine.ELAPSED_MISSION_COUNT_MAX,type=TppScriptVars.TYPE_INT8,value=-127,save=true,category=TppScriptVars.CATEGORY_GAME_GLOBAL},
function this.DumpVarsDeclareTable(varsDeclareTable)
  local dumpedTable={}
  for i,varDecl in ipairs(varsDeclareTable)do
    local value=varDecl.value or "NODEFAULTVALUE"
    if varDecl.arraySize~=nil then
      value="array:"..tostring(value)
    end
    if type(varDecl.value)==nil then
      dumpedTable[varDecl.name]="NODEFAULTVALUE"
    else
      dumpedTable[varDecl.name]=varDecl.value
    end
  end--for varsDeclareTable
  return dumpedTable
end--DumpVarsDeclareTable

function this.DumpEntityClassDictionary()
  local entityClassNames={}

  local categoryList=EntityClassDictionary.GetCategoryList()

  for i,categoryName in ipairs(categoryList)do
    entityClassNames[categoryName]=EntityClassDictionary.GetClassNameList(categoryName)
  end

  return entityClassNames
end

local open=io.open
local Inspect=InfInspect.Inspect

local nl=[[\r\n]]
function this.WriteString(filePath,someString)
  local file,error=open(filePath,"w")
  if not file or error then
    InfCore.Log("ERROR: WriteString could not write "..filePath)
    return
  end

  file:write(someString)
  file:close()
end

--tex writes a table out to file with text header
function this.WriteTable(fileName,header,t,setThisAsGlobal)
  if t==nil then
    return
  end
  InfCore.Log("WriteTable "..fileName)

  local ins=InfInspect.Inspect(t)
  local all="local this="..ins.."\r\n"
  if setThisAsGlobal then--KLUDGE setThisAsGlobal is name of module
    all=all..setThisAsGlobal.."=this".."\r\n"
  end
  all=all.."return this"
  if header then
    all=header.."\r\n"..all
  end

  this.WriteString(fileName,all)
end

function this.DumpToFiles(outDir,moduleTable)
  if moduleTable==nil then
    return
  end
  InfCore.Log("DumpToFiles "..outDir)

  for k,v in pairs(moduleTable) do
    local filename=outDir..k..'.txt'
    local ins=Inspect(v)
    this.WriteString(filename,k.."="..ins)
  end
end

--DEBUGNOW
this.WriteLines = function(fileName,lines)
  local f,err = io.open(fileName,"w")
  if f==nil then
    InfCore.Log("WriteLines open ERROR: "..err)
    return
  else
    for i,line in ipairs(lines)do
      local t = f:write(line.."\n")
    end
    f:close()
  end
end--WriteLines

local function GetIndentLine(indent)
  local indentLine=""
  local indentChar="  "
  for i=1,indent do
    indentLine=indentLine..indentChar
  end
  return indentLine
end--GetIndentLine

--tex sort keys, more convoluted than it needs to be
--TODO: use exeCreateModules log order
--CALLER: WriteMockModules
local function GetSortedTypes(mockModule)
  local typeNames={
    ["<function>"]={},
    ["<userdata>"]={},
    ["table"]={},--tex actually the table names
    ["tables"]={},--the tables recursed (submodule, only 1 level)
    ["value"]={},
  }

  for keyName,value in pairs(mockModule)do
    local keyType="value"
    if typeNames[value]then
      keyType=value
    elseif typeNames[type(value)] then
      keyType=type(value)
    end

    table.insert(typeNames[keyType],keyName)

    if keyType=="table" then
      typeNames.tables[keyName]=GetSortedTypes(value)
    end
  end--for module

  for typeName,keyNames in pairs(typeNames)do
    table.sort(keyNames)
  end
  return typeNames
end--GetSortedTypes

--tex just a dummy stub
--DEBUGNOW TODO: possibly log params (if some debug global or module member set)
local functionLine="function(...)end"

--IN/RETURN: lines
local function GetModuleLinesForSortedTypeNames(module,typeNames,indentLine,lines)
  for typeName,keyNames in pairs(typeNames)do
    for i,keyName in ipairs(keyNames)do
      local value=module[keyName]
      if typeName=="<function>" then
        local valueLine=functionLine--MODULE LOCAL (just above -^-)
        table.insert(lines,indentLine..keyName.."="..valueLine..",")
      elseif typeName=="<userdata>" then
        local valueLine=[["<userdata>"]]
        table.insert(lines,indentLine..keyName.."="..valueLine..",")
      elseif typeName=="table" then
        table.insert(lines,indentLine..keyName.."={")
        lines=GetModuleLinesForSortedTypeNames(module[keyName],typeNames.tables[keyName],indentLine.."  ",lines)
        table.insert(lines,indentLine.."},")
      elseif typeName=="value" then
        local valueLine=tostring(value)
        table.insert(lines,indentLine..keyName.."="..valueLine..",")
      end
    end--for keyNames
  end--for typeNames
  return lines
end--GetModuleLinesForSortedTypeNames
--IN/RETURN: lines
local function GetModuleLinesForExeModuleRefsEntryOrder(mockModule,moduleName,moduleRefs,moduleRefsEntryOrder,indentLine,lines)
  local ignoreKeys={
    __call=true,
    __newindex=true,
    __index=true,
  }

  for i,keyName in ipairs(moduleRefsEntryOrder)do
    if not ignoreKeys[keyName]then
      local mockValue=mockModule[keyName]
      if mockValue=="<function>" then
        local valueLine=functionLine--MODULE LOCAL (above -^-)
        table.insert(lines,indentLine..keyName.."="..valueLine..",")
      elseif mockValue=="<userdata>" then
        local valueLine=[["<userdata>"]]
        table.insert(lines,indentLine..keyName.."="..valueLine..",")
      elseif type(mockValue)=="number"then
        local valueLine=tostring(mockValue)
        table.insert(lines,indentLine..keyName.."="..valueLine..",")
      elseif type(mockValue)=="table"then
        table.insert(lines,indentLine..keyName.."={")
        indentLine=GetIndentLine(2)
        lines=GetModuleLinesForExeModuleRefsEntryOrder(mockModule[keyName],moduleName,moduleRefs[keyName],moduleRefsEntryOrder[keyName],indentLine,lines)
        indentLine=GetIndentLine(1)
        table.insert(lines,indentLine.."},")
      else
        InfCore.Log("ERROR: GetModuleLinesForExeModuleRefsEntryOrder unhandled mockValue:"..tostring(mockValue).." exeModuleRef:"..tostring(moduleRefs[keyName]))
      end--if mockValue type
    end
  end--for moduleRefsEntryOrder

  for keyName,mockValue in pairs(mockModule)do
    local isInExeRef=false
    for i,refKeyName in ipairs(moduleRefsEntryOrder)do
      if keyName==refKeyName then
        isInExeRef=true
        break;
      end
    end--for exeModuleRefsEntryOrder
    if not isInExeRef and not ignoreKeys[keyName] then
      InfCore.Log("GetModuleLinesForSortedTypeNames moduleKeyName not isInExeRef: "..keyName)--DEBUGNOW
      --tex currently only 3 hits, all functions, may need rework if I unify GetModuleLinesForSortedTypeNames, or extend createmodule logging to plain modules (which is handled by that)
      --KLUDGE: just slap them in
      local valueLine=functionLine--MODULE LOCAL (above -^-)
      table.insert(lines,indentLine..keyName.."="..valueLine..",")
    end
  end--for module

  return lines
end--GetModuleLinesForExeModuleRefsEntryOrder
--mockModules: table with all the mock modules
--setThisAsGlobal: module will be written as <moduleName>={, therefore defining itself as global when its loaded, useful for using as vscode lua plugin library
--otherwise will be more standart local this={ ... return this
--IN: IHGenKownModuleNames
function this.WriteMockModules(outDir,mockModules,exeModuleRefs,exeModuleRefsEntryOrder,setThisAsGlobal)
  if mockModules==nil then
    return
  end
  InfCore.Log("WriteMockModules "..outDir)

  for moduleName,mockModule in pairs(mockModules) do
    if this.debugModule then
      InfCore.PrintInspect(mockModule,"WriteMockModules module unsorted "..moduleName)--DEBUGNOW
    end

    --TODO: use exeCreateModules log order
    local typeNames=GetSortedTypes(mockModule)
    --InfCore.PrintInspect(typeNames,"WriteMockModules "..moduleName.." root typeNames")--DEBUGNOW

    local indentLine=""
    local lines={}
    table.insert(lines,"--"..moduleName..".lua")
    table.insert(lines,"--GENERATED: by IHTearDown.GenerateMockModules")
    if setThisAsGlobal then
      table.insert(lines,"--as setThisAsGlobal style")
    end
    if moduleName=="Fox" then
      table.insert(lines,"--GOTCHA: 'fox' and 'Fox' modules collide in Windows due to case insensitivenes")
      table.insert(lines,"--WORKAROUND has tagged on the postfix '_CapitalF', with setThisAsGlobal the module will still be 'Fox'")
      table.insert(lines,"--however MockFox does not currently fix up when setThisAsGlobal false ")
    elseif moduleName=="fox" then
      table.insert(lines,"--GOTCHA: 'fox' and 'Fox' modules collide in Windows due to case insensitivenes")
      table.insert(lines,"--see WORKAROUND on Fox_CapitalF.lua")   
    end
    if IHGenKnownModuleNames.ihHook[moduleName]then
      table.insert(lines,"--NOTE: this is a (mock of) an IHHook module, see the IHHook github for actual info")
    end
    if setThisAsGlobal then
      table.insert(lines,moduleName.."={")
    else
      table.insert(lines,"local this={")
    end

    indentLine=GetIndentLine(1)
    if exeModuleRefs[moduleName]then
      lines=GetModuleLinesForExeModuleRefsEntryOrder(mockModule,moduleName,exeModuleRefs[moduleName],exeModuleRefsEntryOrder[moduleName],indentLine,lines)
    else
      InfCore.Log("WriteMockModules module not in exeModuleRefs:"..moduleName)--DEBUGNOW
      lines=GetModuleLinesForSortedTypeNames(mockModule,typeNames,indentLine,lines)
    end

    table.insert(lines,"}--this")
    if setThisAsGlobal then
      table.insert(lines,"return "..moduleName)
    else
      table.insert(lines,"return this")
    end
    
    local filename=outDir..moduleName..'.lua'
    InfCore.Log("Writing mock module "..filename)--DEBUGNOW
    -- if InfCore.FileExists(filename) then
    --   InfCore.Log("WARNING: mock module file already exists: "..filename)
    -- end
    --tex WORKAROUND KLUDGE fox and Fox modules collide with windows case insensitive filenames (this is the only case of this)
    if moduleName=="Fox" then
      filename=outDir..moduleName.."_CapitalF"..'.lua'
    end

    InfCore.WriteLines(filename,lines)
  end--for mockModules
end--WriteMockModules

--menu stuff
function this.DoTearDown()
  this.GenerateMockModules{buildFromScratch=this.buildFromScratch}
  this.DumpRuntimeVars()
  if this.writeDebugOutput then
    this.DumpRuntimeVarsDebug()
  end
  this.OtherRunTimeAnalyze()
  if IHTearDown2 then
    IHTearDown2.TearDownGameObjectTypes()
  end
  InfCore.Log("DoTearDown done",true)
end

this.registerMenus={
  "foxTearDownMenu",
}

this.foxTearDownMenu={
  noDoc=true,
  nonConfig=true,
  parentRefs={"InfMenuDefs.safeSpaceMenu","InfMenuDefs.inMissionMenu"},
  options={
    "IHTearDown.DoTearDown",
    "IHTearDown.DumpRuntimeVars",
    "IHTearDown.OtherRunTimeAnalyze",
  }
}--foxTearDownMenu

return this
