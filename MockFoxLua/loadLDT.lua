--loadLDT.lua

--tex MockFox host stuff
luaHostType="LDT"

foxGamePath="C:/GamesSD/MGS_TPP/"
foxLuaPath="D:/Projects/MGS/!InfiniteHeaven/!modlua/Data1Lua/"--tex path of tpps scripts (qar luas)
mockFoxPath="D:/Projects/MGS/!InfiniteHeaven/!modlua/MockFoxLua/"--tex path of MockFox scripts

package.path=nil--KLUDGE have mockfox default package path code run, will kill existing / LDT provided package.path
package.cpath=mockFoxPath.."?.dll"--tex for bit.dll TODO: build equivalent cpath.
--
dofile(mockFoxPath.."/loadMockFox.lua")

dofile(mockFoxPath.."/initMock.lua")
--dofile(foxLuaPath.."/init.lua")--tex not quite ready to run straight yet

do
  local chunk,err=loadfile(mockFoxPath.."/startMock.lua")
  --local chunk,err=loadfile(foxLuaPath.."/Tpp/start.lua")--tex not quite ready to run straight yet
  if err then
    print(err)
  else
    local co=coroutine.create(chunk)
    repeat
      local ok,ret=coroutine.resume(co)
      if not ok then
        error(ret)
      end
    until coroutine.status(co)=="dead"
  end
end
