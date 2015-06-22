
-- Helper for compatibility with different ipe-versions.
function mainWindow(model)
   if model.ui.win == nil then
      return model.ui
   else
      return model.ui:win()
   end
end

-- Changes the transformation matrix of a path object to the identitiy
-- matrix without canging the appearance of the object (i.e., the
-- transformation matrix is applied to the objects shape)
function cleanup_matrix(path_obj)
   local matrix = path_obj:matrix()
   local matrix_func = function (point) return matrix end
   local shape = path_obj:shape()
   transform_shape(shape, matrix_func)
   path_obj:setShape(shape)
   path_obj:setMatrix(ipe.Matrix())
end

-- Transform a shape by transforming every point using a matrix
-- returend by matrix_func.  The function matrix_func should take a
-- point and return a matrix (that is then used to transform this
-- point).
--
-- Arcs are also transformed.
function transform_shape(shape, matrix_func)
   for _,path in pairs(shape) do
      for _,subpath in ipairs(path) do
	 -- apply to every point
	 for i,point in ipairs(subpath) do
	    subpath[i] = matrix_func(point) * point
	 end

	 -- apply to arcs
	 if (subpath["type"] == "arc") then
	    local arc = subpath["arc"]
	    local center = arc:matrix():translation()
	    subpath["arc"] = matrix_func(center) * arc
	 end
      end
   end
end

-- Resizes a given shape such that the same transformation also
-- transforms bbox_source to bbox_target.  The transformation is done
-- by translating points of the shape such that all points in the same
-- quadrant with respect to center are translated in the same way.
--
-- Clearly, the center has to lie inside bbox_source.
function resize_shape(shape, center, bbox_source, bbox_target)
   -- assert that the center lies inside bbox_source
   assert(bbox_source:left() < center.x)
   assert(center.x < bbox_source:left() + bbox_source:width())
   assert(bbox_source:bottom() < center.y)
   assert(center.y < bbox_source:bottom() + bbox_source:height())

   -- translation of points to the left/right/top/bottom of the center
   local dx_left = bbox_target:left() - bbox_source:left()
   local dy_bottom = bbox_target:bottom() - bbox_source:bottom()
   local dx_right = bbox_target:width() - bbox_source:width()
   local dy_top = bbox_target:height() - bbox_source:height()

   -- transformation
   local matrix_func = function (point)
      local dx = dx_left
      local dy = dy_bottom
      if (center.x < point.x) then dx = dx + dx_right end
      if (center.y < point.y) then dy = dy + dy_top end
      return ipe.Translation(dx, dy)
   end
   transform_shape(shape, matrix_func)
end

-- Bounding box of a given object that is not currently contained in
-- the page.  If the object is already part of the page, simply use
-- p:bbox(obj).
function bbox(obj, page)
   local objno = #page + 1
   page:insert(objno, obj, nil, page:layers()[1])
   local bbox = page:bbox(objno)
   page:remove(objno)
   return bbox
end

-- The bounding box of all selected objects.
function bbox_of_selected_objects(page)
   local bbox = page:bbox(page:primarySelection())
   for obj = 1, #page, 1 do
      if page:select(obj) then
	 bbox:add(page:bbox(obj))
      end
   end
   return bbox
end

-- Show a warning to the user.
function report_problem(model, text)
   ipeui.messageBox(mainWindow(model), "warning", text, nil, nil)
end

-- Return a table of names associated with decorator symbols.
function decorator_names(model)
   local sheets = model.doc:sheets()
   local symbols = sheets:allNames("symbol")
   local res = {}
   for _, name in pairs(symbols) do
      if name:find("deco/") == 1 then
	 res[#res + 1] = name
      end
   end
   return res
end

-- Check whether a given deco object is usable.
function check_decorator_object(model, deco_obj_group)
   if (deco_obj_group:type() ~= "group") then
      report_problem(model, "The decoration must be a group.")
      return false
   end

   local objects = deco_obj_group:elements()
   local last_obj = table.remove(objects, #objects)
   if (#objects == 0) then
      report_problem(model, "The decoration must be a group of at least two elements (the topmost element is a placeholder for the objects that are decorated, all other elements are the decoration).")
      return false
   end

   for i,deco_obj in ipairs(objects) do
      if (deco_obj:type() ~= "path") then
	 report_problem(model, "Each decoration object needs to be a path.")
	 return false
      end
   end
   return true
end

-- Ask the user for a decorator and run the decoration.
function run_decorator (model)
   local p = model:page()
   local prim = p:primarySelection()
   if (not prim) then
      report_problem(model, "You must select somethings.")
      return
   end
   local bbox_target = bbox_of_selected_objects(p)

   local deco_obj_group = ask_for_decorator(model)
   if (not deco_obj_group) then return end
   if (not check_decorator_object(model, deco_obj_group)) then return end

   local objects = deco_obj_group:elements()
   local last_obj = table.remove(objects, #objects)
   local bbox_source = bbox(last_obj, p)
   local center = ipe.Vector(bbox_source:left() + 0.5 * bbox_source:width(),
			     bbox_source:bottom() + 0.5 * bbox_source:height())

   for i,deco_obj in ipairs(objects) do
      cleanup_matrix(deco_obj)
      local deco_shape = deco_obj:shape()
      
      resize_shape(deco_shape, center, bbox_source, bbox_target)

      deco_obj:setShape(deco_shape)
   end

   local group = ipe.Group(objects)

   model:creation("decoration created", group)
end

-- Asks the user for a decorator and returns the chosen decorator
-- object or nil.
function ask_for_decorator(model)
   local dialog = ipeui.Dialog(mainWindow(model), "Select a decorator.")
   local decorators = decorator_names(model)
   dialog:add("deco", "combo", decorators, 1, 1, 1, 2)
   dialog:add("ok", "button", { label="&Ok", action="accept" }, 2, 2)
   dialog:add("cancel", "button", { label="&Cancel", action="reject" }, 2, 1)
   local r = dialog:execute()
   if not r then return end
   local deco_name = decorators[dialog:get("deco")]
   local symbol = model.doc:sheets():find("symbol", deco_name)
   return symbol:clone()
end

-- Basically create symbol taken from "symbols.lua" with two minor
-- changes.  First, the symbol is created only if the call to
-- check_decorator_object is successful.  Second, the prefix "deco/"
-- is added to the symbols name.
function create_deco_obj(model, num)
   local p = model:page()
   local prim = p:primarySelection()
   if not prim then model.ui:explain("no selection") return end
   if not check_decorator_object(model, p[prim]) then
      model.ui:explain("no selection")
      return
   end
   local str = model:getString("Enter name of new symbol")
   if not str or str:match("^%s*$") then return end
   local name = "deco/" .. str:match("^%s*%S+%s*$")
   local old = model.doc:sheets():find("symbol", name)
   if old then
      local r = ipeui.messageBox(mainWindow(model), "question",
				 "Symbol '" .. name .. "' already exists",
				 "Do you want to proceed?",
				 "okcancel")
      if r <= 0 then return end
   end

   if num == 2 then -- new stylesheet
      local sheet = ipe.Sheet()
      sheet:add("symbol", name, p[prim])
      local t = { label = methods[num].label,
		  sheet = sheet,
      }
      t.redo = function (t, doc)
	 doc:sheets():insert(1, t.sheet:clone())
      end
      t.undo = function (t, doc)
	 doc:sheets():remove(1)
      end
      model:register(t)
   else  -- top stylesheet
      local sheet = model.doc:sheets():sheet(1)
      local t = { label = methods[num].label,
		  original = sheet:clone(),
		  final = sheet:clone(),
      }
      t.final:add("symbol", name, p[prim])
      t.redo = function (t, doc)
	 doc:sheets():remove(1)
	 doc:sheets():insert(1, t.final:clone())
      end
      t.undo = function (t, doc)
	 doc:sheets():remove(1)
	 doc:sheets():insert(1, t.original:clone())
      end
      model:register(t)
   end
end

label = "Decorator"
methods = {
  { label = "decorate", run=run_decorator },
  { label = "create deco-object (in new style sheet)", run=create_deco_obj },
  { label = "create deco-object (in top style sheet)", run=create_deco_obj },
}
