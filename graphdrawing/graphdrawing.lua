----------------------------------------------------------------------
-- Graph drawing ipelet
----------------------------------------------------------------------

label = "Graph drawing"

about = [[
An interface to the TikZ graph drawing library.
]]

local pgf_gd_path = "/usr/local/texlive/2015/texmf-dist/tex/generic/pgf/graphdrawing/lua"
-- local pgf_gd_path = "/home/otfried/Devel/tikz/tex/generic/pgf/graphdrawing/lua"

_G.package.path = pgf_gd_path .. "/?.lua;" .. _G.package.path

local require = _G.require
local V = ipe.Vector

local gd = require "pgf.gd.interface.InterfaceToDisplay"
local lib = require "pgf.gd.lib"

local function boxcenter(box)
  return (box:bottomLeft() + box:topRight()) * 0.5
end

----------------------------------------------------------------------

local algorithm = "tree layout"
local node_distance = 100
local level_distance = 100
local sibling_distance = 100
local extra_options = { { "", "" }, { "", "" }, { "", "" }, }

----------------------------------------------------------------------

local Binding = lib.class { base_class = require "pgf.gd.bindings.Binding" }

function Binding:renderVertex(v)
  local b = self.storage[v]
  b.newpos = V(v.pos.x, v.pos.y)
end

function Binding:renderEdge(e)
  local b = self.storage[e]
  b.newpath = e.path
end

----------------------------------------------------------------------

gd.bind(Binding)

-- these can only be loaded after binding
require "pgf.gd.layered.library"
require "pgf.gd.force.library"
require "pgf.gd.trees.library"
require "pgf.gd.circular.library"

----------------------------------------------------------------------

local option_height = 0

local function option(key, val)
  local new, main = gd.pushOption(key, val, option_height + 1)
  option_height = new
end

----------------------------------------------------------------------

function layout_graph(algorithm, vertices, edges)
  option_height = 0
  option(algorithm, nil)
  option("cut policy", "none")
  option("node distance", node_distance)
  option("level distance", level_distance)
  option("sibling distance", sibling_distance)
  for i = 1,#extra_options do
    local key = extra_options[i][1]
    local value = extra_options[i][2]
    if key and key ~= "" then
      option(key, value)
    end
  end
  
  gd.beginGraphDrawingScope(option_height)
  option_height = option_height + 1
  gd.pushLayout(option_height)

  for _,v in ipairs(vertices) do
    gd.createVertex(v.name, "rectangle", nil, option_height, v)
  end
  for _,e in ipairs(edges) do
    gd.createEdge(e.head.name, e.tail.name, "--", option_height, e)
  end

  gd.runGraphDrawingAlgorithm()
  gd.renderGraph()
  gd.endGraphDrawingScope()
end
  
----------------------------------------------------------------------

local function align_centers(vertices)
  local oldbbox = ipe.Rect()
  local newbbox = ipe.Rect()
  for _,v in ipairs(vertices) do
    oldbbox:add(v.pos)
    newbbox:add(v.newpos)
  end
  return boxcenter(oldbbox) - boxcenter(newbbox)
end

local function find_vertex(m, vertices, curve, head)
  local v = curve[#curve]
  v = v[#v]
  if head then v = curve[1][1] end
  v = m * v
  for i = 1,#vertices do
    if vertices[i].bbox:contains(v) then return vertices[i] end
  end
  return nil
end

local function collect_graph(model)
  local p = model:page()
  local vertices = {}
  local edges = {}
  for i, obj, sel, layer in p:objects() do
    if sel and (obj:type() == "group" or obj:type() == "reference" 
	    or obj:type() == "text") then 
      local name = "v" .. i
      local bbox = p:bbox(i)
      bbox:add(bbox:bottomLeft() - V(5,5))
      bbox:add(bbox:topRight() + V(5,5))
      local pos = boxcenter(bbox)
      vertices[#vertices + 1] = { obj=i, name=name, bbox=bbox, pos=pos }
    end
  end
  for i, obj, sel, layer in p:objects() do
    if sel and obj:type() == "path" then
      local shape = obj:shape()
      local m = obj:matrix()
      if #shape == 1 and shape[1].type == "curve" 
	and shape[1].closed == false then
	local head = find_vertex(m, vertices, shape[1], true)
	local tail = find_vertex(m, vertices, shape[1], false)
	if head and tail then
	  edges[#edges + 1] = { head=head, tail=tail, obj=i }
	end
      end
    end
  end
  return vertices, edges
end

local function parse_path(path, t)
  local shape = { type="curve", closed=false }
  if path[1] ~= "moveto" then return nil end
  local cp = path[2]
  local i = 3
  while i <= #path do
    if path[i] == "lineto" then
      local from = cp
      cp = path[i+1]
      shape[#shape + 1] = { type="segment", t + V(from.x, from.y), 
			    t + V(cp.x, cp.y) }
      i = i + 2
    else
      return nil
    end
  end
  return shape
end

local function print_graph(vertices, edges)
  for _,v in ipairs(vertices) do
    print(v.name, v.pos)
  end
  for _,e in ipairs(edges) do
    print(e.head.name, e.tail.name)
  end
end

----------------------------------------------------------------------

local function apply_graphdrawing(t, doc) 
  local p = doc[t.pno]
  for _,v in ipairs(t.vertices) do
    p:transform(v.obj, ipe.Translation(v.newpos - v.pos + t.translation))
  end
  for _,e in ipairs(t.edges) do
    local path = parse_path(e.newpath, t.translation)
    if path then
      p[e.obj]:setShape( { path } )
    else
      p[e.obj]:setShape({ { type="curve", closed=false,
			    { type="segment", e.head.newpos + t.translation, 
			      e.tail.newpos + t.translation } } } )
    end
    p[e.obj]:setMatrix(ipe.Matrix())
  end
end

local function perform_layout(model, vertices, edges)
  layout_graph(algorithm, vertices, edges)

  local t = { label="graph drawing with " .. algorithm,
	      pno=model.pno, 
	      vno=model.vno, 
	      vertices=vertices,
	      edges=edges,
	      original=model:page():clone(),
	      translation=align_centers(vertices),
	      undo=_G.revertOriginal,
	      redo=apply_graphdrawing,
	    }
  model:register(t)
end

local function run(model, num)
  algorithm = methods[num].label
  local vertices, edges
  vertices, edges = collect_graph(model)
  if #vertices == 0 or #edges == 0 then
    model:warning("No edges or vertices found")
    return
  end
  perform_layout(model, vertices, edges)
end

----------------------------------------------------------------------

local function with_options(model, num)
  local vertices, edges
  vertices, edges = collect_graph(model)
  if #vertices == 0 or #edges == 0 then
    model:warning("No edges or vertices found")
    return
  end
  local algorithms = {}
  for i = 1,#methods-1 do algorithms[#algorithms+1] = methods[i].label end
  local d = ipeui.Dialog(model.ui:win(), "Graph drawing")
  d:add("label1", "label", { label = "Algorithm" }, 1, 1)
  d:add("algorithm", "combo", algorithms, -1, 2)
  d:add("label2", "label", { label = "node distance" }, 0, 1)
  d:add("node-distance", "input", { }, -1, 2)
  d:add("label3", "label", { label = "level distance" }, 0, 1)
  d:add("level-distance", "input", { }, -1, 2)
  d:add("label4", "label", { label = "sibling distance" }, 0, 1)
  d:add("sibling-distance", "input", { }, -1, 2)
  d:add("label5", "label", { label = "Option" }, 0, 1)
  d:add("label6", "label", { label = "Value" }, -1, 2)
  d:set("algorithm", algorithm)
  d:set("node-distance", node_distance)
  d:set("level-distance", level_distance)
  d:set("sibling-distance", sibling_distance)
  for i = 1, #extra_options do
    d:add("option-key-" .. i, "input", { }, 0, 1)
    d:add("option-value-" .. i, "input", { }, -1, 2)
    d:set("option-key-" .. i, extra_options[i][1])
    d:set("option-value-" .. i, extra_options[i][2])
  end
  d:addButton("ok", "&Ok", "accept")
  d:addButton("cancel", "&Cancel", "reject")
  if not d:execute() then return end
  algorithm = algorithms[d:get("algorithm")]
  node_distance = tonumber(d:get("node-distance"))
  level_distance = tonumber(d:get("level-distance"))
  sibling_distance = tonumber(d:get("sibling-distance"))
  for i = 1, #extra_options do
    extra_options[i][1] = d:get("option-key-" .. i) 
    extra_options[i][2] = d:get("option-value-" .. i) 
  end
  perform_layout(model, vertices, edges)
end

methods = {
   { label = "tree layout", run=run },
   { label = "layered layout", run=run },
   { label = "spring layout", run=run },
   { label = "spring electrical layout", run=run },
   { label = "spring electrical layout'", run=run },
   { label = "simple necklace layout", run=run },
   { label = "with options", run=with_options }, 
}

----------------------------------------------------------------------
