----------------------------------------------------------------------
-- presentation goodies for Ipe

--[[

SUMMARY

 This ipelet adds a few goodies for presentation, including
  1. Ability to create beamer-like boxes with/without header
  2. Add a framed box for the selected objects (including text)
  3. A function to deselect all selected on all pages
  4. The boxes can be edited as text/path objects (press E)
  5. A few items can be added to the style sheet to add preferred
     symbolics for box colors etc. This has the benefit that this
     preferences can be changed to affect all boxes (see below).

  The design of these boxes is from Martin Nöllenburg's presentation
  example posted on the Ipe7 wiki page.

STYLESHEET (CHANGING PREFERRED SETTINGS)

 Example style sheet to cascade with presentation.isy is as follows.

---- content of example.isy ---
example removed, not possible to upload this file to the ipe-wiki otherwise
---- end content of example.isy ---

 where:
  tab_header= color of the tab header in a tabbed box
  tab_body  = color of the tab body in a tabbed box
  box_fill  = fill color a box
  box_border= color of the box border
  boxborder = linewidth of the box border

 The preferred box mode (stroked/filled/strokedfilled) can be changed by
 changing the hard-wired value (no stylesheet option) PREFERRED_BOX_MODE below

 With the above style sheet, one can start an empty presentation using
  ipe -sheet presentation -sheet /path/to/example.isy

SHORTCUT

 Shortcuts to these functions can be changed as for other ipelets:
	shortcuts.ipelet_x_presentation = "Key"
 where x is the index (starting 1) of the sub-menu for the function

FILE/AUTHOR HISTORY

 version  0. Initial Release. Zhengdao Wang 2010
 version  1. add a line here if a change is made

LICENSE

 This file can be distributed and modified under the terms of the GNU General
 Public License as published by the Free Software Foundation; either version
 3, or (at your option) any later version.

 This file is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 details.

--]]

----------------------------------------------------------------------

label = "Presentation"

about = [[
	Presentation Goodies: Add boxes around objects, deselect all,
	add tabbed/boxed text.
]]

V = ipe.Vector
indexOf=_G.indexOf

-- table storing the height of the first line box
Height={}
Spacing={}
Has_Height=nil

local c=10 -- corner size

local UNKNOWN=0
local TABBED_TEXT=1
local BOXED_TEXT=2
local BOXED_OTHER=3

local PREFERRED_BOX_MODE="strokedfilled" -- or stroked or filled

local BOX_DIALOG_SIZE={400,140}

-- initialize the Height table
local function init_spacing(model)
	local p=model:page()
	local xx=300
	local iH={}
	local sizes = model.doc:sheets():allNames("textsize")
	for i,size in ipairs(sizes) do
		obj=ipe.Text({textsize=size, minipage=true}, "ABC\n\nDEF", V(xx,xx), xx)
		local layer=p:active(model.vno)
		p:insert(nil, obj, nil, layer)
		obj=ipe.Text({textsize=size, minipage=true}, "ABC", V(xx,xx), xx)
		p:insert(nil, obj, nil, layer)
		iH[#iH+1]=size
	end
	model.doc:runLatex()
	for i=#sizes,1,-1 do
		Height[iH[i]]=xx-p:bbox(#p):bottomLeft().y
		p:remove(#p)
		Spacing[iH[i]]=(xx-p:bbox(#p):bottomLeft().y)/2-Height[iH[i]]
		p:remove(#p)
	end
	Has_Height=1
end

-- generate a path with given properties
local function path(model, shape, props)
	local oldvalues={}
	for k,v in pairs(props) do
		oldvalues[k]=model.attributes[k]
		model.attributes[k]=v
	end
	local obj = ipe.Path(model.attributes, shape)
	for k,v in pairs(props) do
		model.attributes[k]=oldvalues[k]
	end
	if props.pen then obj:set('pen', props.pen) end
	obj:set('pathmode', props.pathmode, props.stroke, props.fill)
	return obj
end

-- create a square box #shape=3
local function boxshape_square(v1, v2)
	return { type="curve", closed=true;
		 { type="segment"; v1, V(v1.x, v2.y) }, -- L
		 { type="segment"; V(v1.x, v2.y), v2 }, -- T
		 { type="segment"; v2, V(v2.x, v1.y) } } -- R
end

-- create a square box with a pointer #shape=6
local function boxshape_square_pointer(v1, v2, v3, v4, v5)
	local dx=v2.x-v1.x
	local dy=v2.y-v1.y
	local v3=v3 or V(v1.x+.4*dx, v2.y)
	local v4=v4 or V(v1.x+.6*dx,v2.y+.3*dy)
	local v5=v5 or V(v1.x+.5*dx,v2.y)
	return { type="curve", closed=true;
		 { type="segment"; v1, V(v1.x, v2.y) }, -- L
		 { type="segment"; V(v1.x, v2.y), v3}, -- T
		 { type="segment"; v3, v4}, -- P
		 { type="segment"; v4, v5}, --P
		 { type="segment"; v5, v2}, -- T
		 { type="segment"; v2, V(v2.x, v1.y) } } -- R
end

-- create a header box: round corner on topRight
local function boxshape_roundTR(v1, v2)
	return { type="curve", closed=true;
		 { type="segment"; v1, V(v1.x, v2.y) },
		 { type="segment"; V(v1.x, v2.y), V(v2.x-c, v2.y) },
		 { type="bezier"; V(v2.x-c, v2.y), V(v2.x-c/2, v2.y),
		 	V(v2.x, v2.y-c/2), V(v2.x, v2.y-c) },
		 { type="segment"; V(v2.x, v2.y-c), V(v2.x, v1.y) } }
end

-- create a body box: round corner on bottom Left
local function boxshape_roundLL(v1, v2)
	return { type="curve", closed=true;
		 { type="segment"; v2, V(v2.x, v1.y) },
		 { type="segment"; V(v2.x, v1.y), V(v1.x+c, v1.y) },
		 { type="bezier"; V(v1.x+c, v1.y), V(v1.x+c/2,v1.y),
		 	V(v1.x, v1.y+c/2), V(v1.x, v1.y+c) },
		 { type="segment"; V(v1.x, v1.y+c), V(v1.x, v2.y) } }
end

-- create a body box: 4 round corners #shape=8
local function boxshape_round(v1, v2)
	return { type="curve", closed=true;
		 { type="segment"; V(v2.x, v2.y-c), V(v2.x, v1.y+c) }, -- R
		 { type="bezier"; V(v2.x,v1.y+c), V(v2.x, v1.y+c/2),
		 	V(v2.x-c/2,v1.y), V(v2.x-c,v1.y)}, -- BR
		 { type="segment"; V(v2.x-c, v1.y), V(v1.x+c, v1.y) }, -- B
		 { type="bezier"; V(v1.x+c, v1.y), V(v1.x+c/2,v1.y),
		 	V(v1.x, v1.y+c/2), V(v1.x, v1.y+c) }, -- BL
		 { type="segment"; V(v1.x, v1.y+c), V(v1.x, v2.y-c) }, -- L
		 { type="bezier"; V(v1.x, v2.y-c), V(v1.x,v2.y-c/2),
		 	V(v1.x+c/2, v2.y), V(v1.x+c, v2.y) }, -- TL
		 { type="segment"; V(v1.x+c, v2.y), V(v2.x-c, v2.y) }, -- T
		 { type="bezier"; V(v2.x-c, v2.y), V(v2.x-c/2,v2.y),
		 	V(v2.x, v2.y-c/2), V(v2.x, v2.y-c) }, -- TR
		}
end

-- create a body box: 4 round corners, with pointer #shape=11
local function boxshape_round_pointer(v1, v2, v3, v4, v5)
	local dx=v2.x-v1.x
	local dy=v2.y-v1.y
	local v3=v3 or V(v1.x+.4*dx, v2.y)
	local v4=v4 or V(v1.x+.6*dx,v2.y+.3*dy)
	local v5=v5 or V(v1.x+.5*dx,v2.y)
	return { type="curve", closed=true;
		 { type="segment"; V(v2.x, v2.y-c), V(v2.x, v1.y+c) }, -- R
		 { type="bezier"; V(v2.x,v1.y+c), V(v2.x, v1.y+c/2),
		 	V(v2.x-c/2,v1.y), V(v2.x-c,v1.y)}, -- BR
		 { type="segment"; V(v2.x-c, v1.y), V(v1.x+c, v1.y) }, -- B
		 { type="bezier"; V(v1.x+c, v1.y), V(v1.x+c/2,v1.y),
		 	V(v1.x, v1.y+c/2), V(v1.x, v1.y+c) }, -- BL
		 { type="segment"; V(v1.x, v1.y+c), V(v1.x, v2.y-c) }, -- L
		 { type="bezier"; V(v1.x, v2.y-c), V(v1.x,v2.y-c/2),
		 	V(v1.x+c/2, v2.y), V(v1.x+c, v2.y) }, -- TL
		 { type="segment"; V(v1.x+c, v2.y), v3}, -- T
		 { type="segment"; v3, v4}, -- P
		 { type="segment"; v4, v5}, --P
		 { type="segment"; v5, V(v2.x-c, v2.y)}, -- T
		 { type="bezier"; V(v2.x-c, v2.y), V(v2.x-c/2,v2.y),
		 	V(v2.x, v2.y-c/2), V(v2.x, v2.y-c) }, -- TR
		}
end

-- parse the values from a group obj
local function parse_group_values(model,prim)
	local fs = model.doc:sheets():find("layout").framesize
	local p=model:page()
	local bbox=p:bbox(prim)
	local pos=V(bbox:bottomLeft().x, bbox:topRight().y)

	local elements=p[prim]:elements()
	if #elements==4 then
		local hb,bb,ht,bt=elements[1],elements[2],elements[3],elements[4]
		if hb:type()=="path" and bb:type()=="path" and
			ht:type()=="text" and bt:type()=="text" then
			local values={htext=ht:text(),
				btext=bt:text(),
				pinned=(p[prim]:get("pinned")=="horizontal"),
				fwidth=string.format('%.2f',
					(bbox:topRight().x-bbox:bottomLeft().x)/fs.x),
				hcolor=hb:get("fill"),
				bcolor=bb:get("fill"),
				size=ht:get("textsize")}
			return TABBED_TEXT,values,pos
		end
	else
		local bb,bt=elements[1],elements[2]
		if bb:type()=="path" and #bb:shape()==1 and
			bb:shape()[1].closed==true and
			(#bb:shape()[1]==3 or #bb:shape()[1]==8 or
			#bb:shape()[1]==6 or #bb:shape()[1]==11) then
			if bt:type()=="text" then
				local values={btext=bt:text(),
					pinned=(p[prim]:get("pinned")=="horizontal"),
					size=bt:get("textsize"),
					fwidth=string.format('%.2f',
						(bbox:topRight().x-bbox:bottomLeft().x)/fs.x),
					bcolor=bb:get("fill")}
				if #bb:shape()[1]==6 then
					pos=V(pos.x,bb:shape()[1][1][2].y)
				elseif #bb:shape()[1]==11 then
					pos=V(pos.x,bb:shape()[1][10][2].y)
				end
				return BOXED_TEXT,values,pos
			else
				return BOXED_OTHER
			end
		end
	end
	return UNKNOWN
end

function mainWindow(model)
   if model.ui.win == nil then
      return model.ui
   else
      return model.ui:win()
   end
end

-- Edit the values for the frame
local function edit_tabbed_values(model,values)
        local d = ipeui.Dialog(mainWindow(model), "Create tabbed text")
	local colors = model.doc:sheets():allNames("color")
	local sizes = model.doc:sheets():allNames("textsize")
	d:add("hlabel", "label", { label="Enter Header" }, 1, 1, 1, 1)
	d:add("hcolor", "combo", colors, 1, 4)
	d:add("htext", "input", { syntax="latex" }, 2, 1, 1, 4)
	d:add("blabel", "label", { label="Enter Body"}, 3, 1, 1, 3)
	d:add("bcolor", "combo", colors, 3, 4)
	d:add("btext", "text", { syntax="latex" }, 4, 1, 1, 4)
	d:add("size", "combo", sizes, 5, 1)
	d:add("wlabel", "label", { label="width [0-1]"}, 5, 2, 1, 2)
	d:add("fwidth", "input", {size=2}, 5, 3, 1, 1)
	d:add("pinned", "checkbox", { label="pinned"}, 5, 4)
	d:add("ok", "button", { label="&Ok", action="accept" }, 6, 4)
	d:add("cancel", "button", { label="&Cancel", action="reject" }, 6, 3)
	_G.addEditorField(d, "btext", 6, 2)
	d:setStretch("row", 2, 1)
	d:setStretch("column", 1, 1)
	d:set("fwidth", "0.8")
	d:set("pinned", 1)

	if indexOf("tab_header", colors) then
		d:set("hcolor", indexOf("tab_header", colors))
	elseif indexOf("darkblue", colors) then
		d:set("hcolor", indexOf("darkblue", colors))
	else
		d:set("hcolor", indexOf("black", colors))
	end

	if indexOf("tab_body", colors) then
		d:set("bcolor", indexOf("tab_body", colors))
	elseif indexOf("lightgray", colors) then
		d:set("bcolor", indexOf("lightgray", colors))
	else
		d:set("bcolor", indexOf("white", colors))
	end

	if values then
		for k,v in pairs(values) do
			if k=="hcolor" or k=="bcolor" then v=indexOf(v, colors) end
			if k=="size" then v=indexOf(v, sizes) end
			d:set(k, v)
		end
	end

	local r = d:execute(prefs.editor_size)
	if not r then return end
	local newvalues={}
	newvalues.htext=d:get("htext")
	newvalues.btext=d:get("btext")
	newvalues.pinned=d:get("pinned")
	newvalues.fwidth=d:get("fwidth")
	newvalues.size=sizes[d:get("size")]
	newvalues.hcolor=colors[d:get("hcolor")]
	newvalues.bcolor=colors[d:get("bcolor")]
--	if newvalues.fwidth=="" or tonumber(newvalues.fwidth)>.99 then
--		newvalues.pinned=true
--	end
	return newvalues
end

-- measure the height a piece of given text
local function measure_height(model,text,size,width)
	local p=model:page()
	local obj= ipe.Text(model.attributes, text, V(0,0), width)
	obj:set('textsize', size)
	local layer=p:active(model.vno)
	p:insert(nil, obj, nil, layer)
	if not model.doc:runLatex() then
		p:remove(#p)
		return 100
	end
	local bbox=p:bbox(#p)
	p:remove(#p)
	return bbox:topRight().y-bbox:bottomLeft().y
end

-- Create boxed text
local function create_boxed(model,values, pos, prim)
	local fs = model.doc:sheets():find("layout").framesize
	local p = model:page()
	local editmode=(prim~=nil)

	local width fwidth=tonumber(values.fwidth)

	if not fwidth or fwidth<0 or fwidth>1 then
		width=fs.x
		fwidth=1
	else
		width=fwidth*fs.x
	end

	-- spacing
	local s=Spacing[values.size]
	local h=Height[values.size]
	if not s or not h then
		init_spacing(model)
		s=Spacing[values.size]
		h=Height[values.size]
	end

	local bheight=measure_height(model,values.btext,values.size,width-2*s)

	-- location
	if not pos then
		x1=fs.x/2-width/2
		x2=fs.x/2+width/2
		y2=fs.y/2
		y1=y2-bheight-1.8*s
	else
		x1=pos.x
		x2=x1+width
		y2=pos.y
		y1=y2-bheight-1.8*s
	end
	if fwidth>.99 then x1,x2=0,fs.x end

	-- body text
	pos=V(x1+s, y2-s)
	local bt= ipe.Text(model.attributes, values.btext, pos, width-2*s)
	bt:set('textsize', values.size)

	-- body box
	local shape2
	if values.rounded then
		shape2 = { boxshape_round(V(x1,y1), V(x2,y2)) }
	else
		shape2 = { boxshape_square(V(x1,y1), V(x2,y2)) }
	end
	local bb = path(model, shape2,
		{pathmode='filled', fill=values.bcolor, stroke="white"})

	-- group object
	local elements={bb,bt}
	local obj=ipe.Group(elements)
	-- obj:setMatrix(p[prim]:matrix()) -- currently not working
	if values.pinned then obj:set('pinned', 'horizontal') end

	if editmode then
		local t={original=p[prim]:clone(),
				label="edit boxed text",
				pno=model.pno,
				vno=model.vno,
				primary=prim,
				final=obj }
		t.undo = function (t, doc)
					 doc[t.pno]:replace(t.primary, t.original)
				 end
		t.redo = function (t, doc)
					 doc[t.pno]:replace(t.primary, t.final)
				 end
		model:register(t)
	else
		model:creation("create boxed text", obj)
		-- model.doc:runLatex() -- may crash the thing
	end
end

-- Create the requested object from values
local function create_tabbed(model,values, pos, prim)
	local fs = model.doc:sheets():find("layout").framesize
	local p = model:page()
	local editmode=(prim~=nil)

	local width fwidth=tonumber(values.fwidth)

	if not fwidth or fwidth<0 or fwidth>1 then
		width=fs.x
		fwidth=1
	else
		width=fwidth*fs.x
	end

	-- spacing
	local s=Spacing[values.size]
	local h=Height[values.size]
	if not s or not h then
		init_spacing(model)
		s=Spacing[values.size]
		h=Height[values.size]
	end

	local bheight=measure_height(model,values.btext,values.size,width-2*s)

	-- location
	if not pos then
		x1=fs.x/2-width/2
		x2=fs.x/2+width/2
		y2=fs.y/2
		y1=y2-h-bheight-3.8*s
	else
		x1=pos.x
		x2=x1+width
		y2=pos.y
		y1=y2-h-bheight-3.8*s
	end
	if fwidth>.99 then x1,x2=0,fs.x end

	-- header text
	pos=V(x1+s, y2-s)
	local ht= ipe.Text(model.attributes, values.htext, pos, width-2*s)
	ht:set('stroke', 'white')
	ht:set('textsize', values.size)

	-- body text
	pos=V(x1+s, y2-s-h-2*s)
	local bt= ipe.Text(model.attributes, values.btext, pos, width-2*s)
	bt:set('textsize', values.size)

	-- header box
	local shape1 = { boxshape_roundTR(V(x1,y2-h-2*s), V(x2,y2)) }
	local hb = path(model, shape1,
		{pathmode='filled', fill=values.hcolor, stroke="white"})
		hb:set('pathmode', 'filled', "white", values.hcolor)

	-- body box
	local shape2 = { boxshape_roundLL(V(x1,y1), V(x2,y2-h-2*s)) }
	local bb = path(model, shape2,
		{pathmode='filled', fill=values.bcolor, stroke="white"})

	-- group object
	local elements={hb,bb,ht,bt}
	local obj=ipe.Group(elements)
	if values.pinned then obj:set('pinned', 'horizontal') end

	if editmode then
		local t={original=p[prim]:clone(),
				label="edit tabbed text",
				pno=model.pno,
				vno=model.vno,
				primary=prim,
				final=obj }
		t.undo = function (t, doc)
					 doc[t.pno]:replace(t.primary, t.original)
				 end
		t.redo = function (t, doc)
					 doc[t.pno]:replace(t.primary, t.final)
				 end
		model:register(t)
	else
		model:creation("create tabbed text", obj)
		-- model.doc:runLatex() -- may crash the thing
	end

end

-- create the dialog for editing box properties
local function box_property_dialog(model)
	local colors = model.doc:sheets():allNames("color")
	local pens= model.doc:sheets():allNames("pen")
	local pathmodes = {"stroked", "strokedfilled", "filled"}
	local d = ipeui.Dialog(mainWindow(model), "Edit box properties")

	d:add("rounded", "checkbox", { label="Round Corner"}, 1, 1, 1, 1)
	d:add("pointer", "checkbox", { label="Pointer"}, 1, 2, 1, 1)
	d:add("mlabel", "label", { label="Mode"}, 2, 1)
	d:add("pathmode", "combo", pathmodes, 2, 2)
	d:add("flabel", "label", { label="Fill Color" }, 3, 1)
	d:add("fill", "combo", colors, 3, 2)
	d:add("slabel", "label", { label="Stroke Color" }, 4, 1)
	d:add("stroke", "combo", colors, 4, 2)
	d:add("plabel", "label", { label="Line Width"}, 5, 1)
	d:add("pen", "combo", pens, 5, 2)
	d:add("cancel", "button", { label="&Cancel", action="reject" }, 6, 1)
	d:add("ok", "button", { label="&Ok", action="accept" }, 6, 2)
	d:setStretch("column", 2, 1)
	return d
end

-- edit a box object
local function edit_box(model, prim)
	local colors = model.doc:sheets():allNames("color")
	local pens= model.doc:sheets():allNames("pen")
	local pathmodes = {"stroked", "strokedfilled", "filled"}

	local p=model:page()
	local elements=p[prim]:elements()
	local bb=elements[1]
	local bbs=bb:shape()[1]

	local d=box_property_dialog(model)

	-- default values
	d:set("rounded", #bbs>=7)
	d:set("pathmode", indexOf(bb:get('pathmode'),pathmodes))
	d:set("pointer", #bbs==6 or #bbs==11)
	if indexOf(bb:get('stroke'),colors) then
		d:set("stroke", indexOf(bb:get('stroke'),colors) )
	elseif not model.attributes.stroke then
		d:set("stroke", indexOf(model.attributes.stroke,colors) )
	end
	if indexOf(bb:get('fill'),colors) then
		d:set("fill", indexOf(bb:get('fill'),colors) )
	elseif not model.attributes.fill then
		d:set("fill", indexOf(model.attributes.fill,colors) )
	end
	if indexOf(bb:get('pen'),pens) then
		d:set("pen", indexOf(bb:get('pen'),pens) )
	elseif not model.attributes.pen then
		d:set("pen", indexOf(model.attributes.pen,pens) )
	end

	local r = d:execute(BOX_DIALOG_SIZE)
	if not r then return end
	local pathmode=pathmodes[d:get("pathmode")]
	local stroke=colors[d:get("stroke")]
	local fill=colors[d:get("fill")]
	local pen=pens[d:get("pen")]

	local boxshape
	if d:get('rounded') and d:get('pointer') then
		boxshape=boxshape_round_pointer
	elseif d:get('rounded') and not d:get('pointer') then
		boxshape=boxshape_round
	elseif not d:get('rounded') and d:get('pointer') then
		boxshape=boxshape_square_pointer
	else
		boxshape=boxshape_square
	end

	-- v1=BL, v2=TR, v3=P1, v4=P2, v5=P3. Pointer=(P1,P2,P3)
	local v1,v2,v3,v4,v5,shape
	if #bbs==3 then
		v1=bbs[1][1];v2=bbs[2][2]
		shape={ boxshape(v1,v2) }
	elseif #bb:shape()[1]==6 then
		v1=bbs[1][1];v3=bbs[2][2]; v4=bbs[3][2]; v5=bbs[4][2];
		v2=bbs[5][2];
		shape={ boxshape(v1,v2,v3,v4,v5) }
	elseif #bb:shape()[1]==8 then
		v1=V(bbs[5][1].x,bbs[3][1].y)
		v2=V(bbs[1][1].x,bbs[7][1].y)
		shape={ boxshape(v1,v2) }
	elseif #bb:shape()[1]==11 then
		v1=V(bbs[5][1].x,bbs[3][1].y)
		v2=V(bbs[1][1].x,bbs[7][1].y)
		v3=bbs[7][2]; v4=bbs[8][2]; v5=bbs[9][2];
		shape={ boxshape(v1,v2,v3,v4,v5) }
	end

	local obj = path(model, shape,
		{pen=pen, pathmode=pathmode, stroke=stroke, fill=fill})

	elements[1]=obj
	local final = ipe.Group(elements)
	final:setMatrix(p[prim]:matrix())

	local t = { label="edit box", pno=model.pno, vno=model.vno,
					layer=p:active(model.vno),
					original=p[prim]:clone(),
					primary=prim, final=final }
	t.undo = function (t, doc)
				 doc[t.pno]:replace(t.primary, t.original)
			 end
	t.redo = function (t, doc)
				 doc[t.pno]:replace(t.primary, t.final)
			 end
	model:register(t)
end

-- Edit a group object
local function action_edit_group(model,prim,obj)
	local otype,values,pos=parse_group_values(model,prim)
	if otype==UNKNOWN then
		model:warning("Cannot edit this object")
		return
	elseif otype==TABBED_TEXT then
		local newvalues=edit_tabbed_values(model, values)
		if not newvalues then return end
		if newvalues.htext=="" then
			newvalues.rounded=true
			create_boxed(model,newvalues,pos,prim)
		else
			create_tabbed(model,newvalues,pos,prim)
		end
	elseif otype==BOXED_OTHER or otype==BOXED_TEXT then
		edit_box(model,prim)
	end
end

-- saving the old function
function _G.MODEL:presentation_backup_actinon_edit () end
_G.MODEL.presentation_backup_action_edit = _G.MODEL.action_edit

-- modify the global edit action
function _G.MODEL:action_edit()
	local p = self:page()
	local prim = p:primarySelection()
	if not prim then
	   self:presentation_backup_action_edit()
	   return 
	end
	local obj = p[prim]
	if obj:type() == "group" then
	   action_edit_group(self, prim, obj)
	else
	   self:presentation_backup_action_edit()
	end
end

-- Run to create a new object
function tabbedboxed(model)
	local values=edit_tabbed_values(model)
	if not values then return end
	if values.htext=="" then
		values.rounded=true
		create_boxed(model,values)
	else
		create_tabbed(model,values)
	end
end

-- deselect all selected
function deselectAll(model)
	local doc = model.doc
	for i,p in doc:pages() do
		p:deselectAll()
	end
end

-- box the selected objects
function boxit(model)
	local p=model:page()
	local box = ipe.Rect()
	local elements={0}
	for i,obj,sel,layer in p:objects() do
		if sel then
			box:add(p:bbox(i))
			elements[#elements+1]=obj:clone()
		end
	end
	if #elements==1 then
		model.ui:explain('No selection to box')
		return
	end
	local s=8
	local layout = model.doc:sheets():find("layout")
--	local maxx=layout.framesize.x

	local x1=box:bottomLeft().x-s
--	if x1 < 0 then x1 = 0 end
	local y1=box:bottomLeft().y-s

	local x2=box:topRight().x+s
--	if x2 > maxx then x2 = maxx end
	local y2=box:topRight().y+s

	local d=box_property_dialog(model)

	local colors = model.doc:sheets():allNames("color")
	local pens= model.doc:sheets():allNames("pen")
	local pathmodes = {"stroked", "strokedfilled", "filled"}

	-- default values
	d:set("rounded", true)

	d:set("pathmode", indexOf(PREFERRED_BOX_MODE,pathmodes))

	if indexOf("box_border",colors) then
		d:set("stroke", indexOf("box_border",colors))
	elseif model.attributes.stroke then
		d:set("stroke", indexOf(model.attributes.stroke,colors) )
	end

	if indexOf("box_fill",colors) then
		d:set("fill", indexOf("box_fill",colors))
	elseif model.attributes.fill then
		d:set("fill", indexOf(model.attributes.fill,colors) )
	end
	
	if indexOf("boxborder",pens) then
		d:set("pen", indexOf("boxborder",pens))
	elseif model.attributes.pen then
		d:set("pen", indexOf(model.attributes.pen,pens) )
	end

	local r = d:execute(BOX_DIALOG_SIZE)

	if not r then return end
	local pathmode=pathmodes[d:get("pathmode")]
	local stroke=colors[d:get("stroke")]
	local fill=colors[d:get("fill")]
	local pen=pens[d:get("pen")]

	local boxshape
	if d:get('rounded') and d:get('pointer') then
		boxshape=boxshape_round_pointer
	elseif d:get('rounded') and not d:get('pointer') then
		boxshape=boxshape_round
	elseif not d:get('rounded') and d:get('pointer') then
		boxshape=boxshape_square_pointer
	else
		boxshape=boxshape_square
	end

	local shape = { boxshape(V(x1,y1), V(x2,y2)) }

	local obj = path(model, shape, {pen=pen, pathmode=pathmode, stroke=stroke, fill=fill})

	elements[1]=obj
	local final = ipe.Group(elements)

	local t = { label="add box", pno=model.pno, vno=model.vno,
					layer=p:active(model.vno), object=obj,
					selection=model:selection(),
					undo=_G.revertOriginal,
					original=p:clone(),
					final=final }
	t.redo = function (t, doc)
				 local p = doc[t.pno]
				 for i = #t.selection,1,-1 do p:remove(t.selection[i]) end
				 p:insert(nil, t.final, 1, t.layer)
			 end
	model:register(t)
end

methods = {
  { label = "Box It", run=boxit},
  { label = "Tabbed/Boxed Text", run=tabbedboxed},
  { label = "Deselect All", run=deselectAll},
}

