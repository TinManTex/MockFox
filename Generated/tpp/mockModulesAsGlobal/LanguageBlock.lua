--LanguageBlock.lua
--GENERATED: by IHTearDown.GenerateMockModules
--as setThisAsGlobal style
LanguageBlock={
  LANGUAGE_BLOCK_ID_INVALID=0,
  LANGUAGE_BLOCK_STATE_EMPTY=0,
  LANGUAGE_BLOCK_STATE_PROCESSING=1,
  LANGUAGE_BLOCK_STATE_INACTIVE=2,
  LANGUAGE_BLOCK_STATE_ACTIVE=3,
  TRANSITION_LOADED=0,
  TRANSITION_ACTIVATED=1,
  TRANSITION_DEACTIVATED=2,
  TRANSITION_EMPTIED=3,
  GetLanguageBlockId=function(...)end,
  GetCurrentLanguageBlockId=function(...)end,
  Create=function(...)end,
  Load=function(...)end,
  Activate=function(...)end,
  Deactivate=function(...)end,
  IsProcessing=function(...)end,
  GetLanguageBlockState=function(...)end,
}--this
return LanguageBlock