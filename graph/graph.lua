----------------------------------------------------------------------
-- graph ipelet
----------------------------------------------------------------------
label = "Graph"

about = [[ Some features making it easier to work with graphs. ]]

local deactivateGraphMode = false
local moveInvisibleObjects = false

function toggleGraphMode ()
   if deactivateGraphMode then
      deactivateGraphMode = false
   else 
      deactivateGraphMode = true
   end
end

function toggleMoveInvisible ()
   if moveInvisibleObjects then
      moveInvisibleObjects = false
   else 
      moveInvisibleObjects = true
   end
end

local editing = false
local currMarkId = nil

--------------------------------------------------------------------------------
-- add an edit action for marks ------------------------------------------------

-- saving the old function
function _G.MODEL:graph_backup_actinon_edit () end
_G.MODEL.graph_backup_action_edit = _G.MODEL.action_edit

-- adding support for objects of type reference
function _G.MODEL:action_edit()
   if deactivateGraphMode then
      self:graph_backup_action_edit()
      return
   end
   local p = self:page()
   local prim = p:primarySelection()
   if not prim then
      self:graph_backup_action_edit()
      return 
   end
   local obj = p[prim]
   if obj:type() == "reference" then
      action_edit_reference (self, prim, obj)     
   else
      self:graph_backup_action_edit()
   end
end


-- starting to edit a mark
function action_edit_reference(model, prim, obj)
   editing = true
   currMarkId = prim
   local p = model:page()

   local pos = obj:matrix() * obj:position()
   -- print(pos)

   -- creating a circle at the position of the mark
   local ellipse = {type="ellipse"}
   ellipse[1] = ipe.Matrix({10, 0, 0, 10, pos.x, pos.y})
   -- print(ellipse[1])
   local circ = ipe.Path(model.attributes, {ellipse})
   p:insert(nil, circ, 0, p:layerOf(prim))

   -- edit the circle instead of the mark itself
   model:action_edit_path(#p, circ)

   -- print("test")
end

--------------------------------------------------------------------------------
-- pressing a key while editing the cycle --------------------------------------

-- saving old function
function _G.EDITTOOL:graph_backup_key(code, modifiers, text) end
_G.EDITTOOL.graph_backup_key = _G.EDITTOOL.key

-- overwriting
function _G.EDITTOOL:key(code, modifiers, text)
   -- The parameters of the key() function have changed in version
   -- 7.1.7.  Thus, we potentially have to remap the parameters.
   if text == nil then
      text = code
   end
   self:graph_backup_key(code, modifiers, text)
   if deactivateGraphMode then return end

   -- react if and only if we are currently editing a mark and key ESC
   -- or SPACE is pressed
   -- if text ~= "\027" and code ~= 0x20 then return end
   if text ~= "\027" and text ~= " " then return end

   if not editing then return end
   
   editing = false

   -- finding new and old position
   local p = self.model:page()
   local circ = p[#p]
   local mark = p[currMarkId]
   local oldPos = mark:matrix() * mark:position()
   local newPos = circ:shape()[1][1]:translation()

   -- remove the intermediate step of moving the cycle from the undo
   -- stack and remove the cycle itself
   local undoSt = self.model.undo
   p:remove(#p)
   table.remove(undoSt)

   -- new action for the undo stack moving the mark and all endpoints
   -- ending at the mark
   local t = { label = "edit reference",
	       pno = self.model.pno,
	       vno = self.model.vno,
	       selection = self.model:selection(),
	       original = self.model:page():clone(),
	       matrix = matrix,
	       undo = _G.revertOriginal,}
   t.redo = function (t, doc)
      p:transform(currMarkId, ipe.Translation(newPos-oldPos))
      moveEndpoints(oldPos, newPos, p, self.model)
   end
   self.model:register(t)
end

-- function moving all endpoints and intermediate points in polylines
-- to newPos, if the squared distance to oldPos is at most sqEps
local sqEps = 1
function moveEndpoints(oldPos, newPos, p, model)
   -- print(model.vno)
   for i, obj, sel, layer in p:objects() do
      -- do nothing if the object is invisible and invisible objects
      -- should not be moved
      if not p:visible(model.vno, layer) and
	 not moveInvisibleObjects then
	 goto continue
      end
      -- do nothing if it is not a path
      if obj:type() ~= "path" then
	 goto continue
      end
      local shape = obj:shape()
      for _, subPath in ipairs(shape) do
	 if (subPath["type"] == "curve") then
	    for _,seg in ipairs(subPath) do
	       if (seg["type"] == "segment") then
		  for j, point in ipairs(seg) do
		     -- print(j, point, oldPos)
		     if (obj:matrix() * point - oldPos):sqLen() < sqEps then
			seg[j] = obj:matrix():inverse() * newPos
			-- print("test", seg[j])
		     end 
		  end
	       elseif (seg["type"] == "spline") then
		  if (obj:matrix() * seg[1] - oldPos):sqLen() < sqEps then
		     seg[1] = obj:matrix():inverse() * newPos
		  end
		  if (obj:matrix() * seg[#seg] - oldPos):sqLen() < sqEps then
		     seg[#seg] = obj:matrix():inverse() * newPos
		  end
	       end
	    end
	 end
	 obj:setShape(shape)
      end
      ::continue::
   end
end


--------------------------------------------------------------------------------
-- working with groups ---------------------------------------------------------

local function regroup(elem)
   local groupElem = {}
   for i, obj in ipairs(elem) do
      if obj[1] ~= nil then
	 groupElem[#groupElem + 1] =  regroup(obj)
      else 
	 groupElem[#groupElem + 1] = obj
      end
   end
   return ipe.Group(groupElem)
end

local function ungroup(group)
   local elem = group:elements()
   local plainElem = {}
   for i, obj in ipairs(elem) do
      if (obj:type() == "group") then
	 local subElem, subPlainElem = ungroup(obj)
	 elem[i] = subElem;
	 for _, subObj in ipairs(subPlainElem) do
	    table.insert(plainElem, subObj)
	 end
      else
	 table.insert(plainElem, obj)
      end
   end
   return elem, plainElem
end

--------------------------------------------------------------------------------
-- shorten paths ---------------------------------------------------------------

function shortenObj(obj, lenSource, lenTarget)
   if obj:type() == "path" then
      local shape = obj:shape()
      for _, subPath in ipairs(shape) do
	 local first = subPath[1]
	 local last = subPath[#subPath]
	 
	 local p1 = obj:matrix() * first[1]
	 local p2 = obj:matrix() * first[2]
	 local pDelta = p2 - p1
	 local pNorm = pDelta:normalized()
	 local newP1 =  p1 + pNorm*lenSource
	 
	 local q1 = obj:matrix() * last[#last]
	 local q2 = obj:matrix() * last[#last - 1]
	 local qDelta = q2 - q1
	 local qNorm = qDelta:normalized()
	 local newQ1 = q1 + qNorm*lenTarget

	 first[1] = obj:matrix():inverse() * newP1
	 last[#last] = obj:matrix():inverse() * newQ1
      end
      obj:setShape(shape)
   end
end

function getString(model, string)
   if ipeui.getString ~= nil then
      return ipeui.getString(model.ui, "Enter length")
   else 
      return model:getString("Enter length")
   end
end

function shorten(model, num)
   num = num - 2
   local lenTarget = 0
   local lenSource = 0
   -- local str = ipeui.getString(model.ui, "Enter length")
   -- local str = model:getString("Enter length")
   local str = getString(model, "Enter length")
   if not str or str:match("^%s*$)") then return end
   if num == 1 then -- shorten target
      lenTarget = tonumber(str)
   elseif num == 2 then -- shorten source
      lenSource = tonumber(str)
   elseif num == 3 then -- shorten both
      lenTarget = tonumber(str)
      lenSource = tonumber(str)
   end

   -- start to edit the edges
   local t = { label = "shorten edges",
	       pno = model.pno,
	       vno = model.vno,
	       selection = model:selection(),
	       original = model:page():clone(),
	       matrix = matrix,
	       undo = _G.revertOriginal,}
   t.redo = function (t, doc)
      local p = doc[t.pno]
      for _, i in ipairs(t.selection) do
	 p:setSelect(i, 2)
      end
      local p = doc[t.pno]
      for i, obj, sel, layer in p:objects() do
	 if sel and obj:type() == "group" then
	    local elem, plainElem = ungroup(obj)
	    for _,subobj in pairs(plainElem) do
	       shortenObj(subobj, lenSource, lenTarget)
	    end
	    p:replace(i, regroup(elem))
	 elseif sel then
	    shortenObj(obj, lenSource, lenTarget)
	 end	    
      end
   end
   model:register(t)
end


methods = {
   { label = "toggle graph mode", run=toggleGraphMode },
   { label = "toggle move invisible", run=toggleMoveInvisible },
   { label = "shorten target", run=shorten },
   { label = "shorten source", run=shorten },
   { label = "shorten both", run=shorten },
}

----------------------------------------------------------------------
