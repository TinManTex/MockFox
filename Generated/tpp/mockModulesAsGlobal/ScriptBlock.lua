--ScriptBlock.lua
--GENERATED: by IHTearDown.GenerateMockModules
--as setThisAsGlobal style
ScriptBlock={
  SCRIPT_BLOCK_ID_INVALID=0,
  SCRIPT_BLOCK_STATE_EMPTY=0,
  SCRIPT_BLOCK_STATE_PROCESSING=1,
  SCRIPT_BLOCK_STATE_INACTIVE=2,
  SCRIPT_BLOCK_STATE_ACTIVE=3,
  TRANSITION_LOADED=0,
  TRANSITION_ACTIVATED=1,
  TRANSITION_DEACTIVATED=2,
  TRANSITION_EMPTIED=3,
  GetScriptBlockId=function(...)end,
  GetCurrentScriptBlockId=function(...)end,
  Load=function(...)end,
  Reload=function(...)end,
  Activate=function(...)end,
  Deactivate=function(...)end,
  IsProcessing=function(...)end,
  GetScriptBlockState=function(...)end,
  UpdateScriptsInScriptBlocks=function(...)end,
  ExecuteInScriptBlocks=function(...)end,
}--this
return ScriptBlock