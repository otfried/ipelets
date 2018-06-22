-----------------------------------------------------------------------
-- ipelet for drawing editor Ipe to insert PDF/IPE files
-----------------------------------------------------------------------
--[[

   This file is an extension of the drawing editor Ipe (ipe7.sourceforge.net)

   Copyright (c) 2010 Zhengdao Wang

   This file can be distributed and modified under the terms of the GNU General
   Public License as published by the Free Software Foundation; either version
   3, or (at your option) any later version.

   This file is distributed in the hope that it will be useful, but WITHOUT ANY
   WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
   FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
   details.

   You can find a copy of the GNU General Public License at
   "http://www.gnu.org/copyleft/gpl.html", or write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

   1) Only the first page is included, even if there are multiple pages.
   2) The content will be grouped into one 'group' object in Ipe.
   3) The object will be inserted at the center of the current Ipe page.
   4) It depends on availability of ghostscript and pdftoipe.
   5) It has not been fully tested. Absolutely NO WARRANTY.

   UPDATE 21/06/2018 (by Christopher Weyand):
   - updated not functioning code
   - removed eps file support
   - allow spaces in file path
   - only tested on Ubuntu 16.04 and 18.04
--]]

label = "Insert PDF/IPE"

about = [[
Insert PDF/IPE files.
]]

function run(model)
	-- get filename
	dir=dir or "."

	local file=ipeui.fileDialog(nil, "open", "Import EPS/PDF File",
		{"PDF, IPE (*.pdf *.ipe)", "*.pdf;*.ipe"},
		dir, nil)
	if not file then return end
	dir=string.gsub(file, "(.*/)(.*)", "%1")

	local tmpipe="/tmp/ipelet-eps.ipe"

	-- convert to an Ipe file if not already one
	local format= ipe.fileFormat(file)
	if format~="xml" then
		-- convert file to IPE
		local ret=0
		ret=_G.os.execute("pdftoipe \"" .. file .. "\" "
			.. tmpipe .. " >/dev/null 2>/dev/null")
		if not ret then
			model:warning ("fail to convert to intermediate IPE")
			return
		end
		file=tmpipe
	end

	-- load the doc
	local doc = assert(ipe.Document(file))

	local layout = model.doc:sheets():find("layout")
	local fs = layout.framesize

	-- take first page from file and insert on the current IPE -- one group object of the page content
	for i,p in doc:pages() do
		local box = ipe.Rect()
		for i,obj,sel,layer in p:objects() do
			box:add(p:bbox(i))
		end

		local nx = (fs.x - box:width()) / 2
		local ny = (fs.y - box:height()) / 2
		local trans = ipe.Vector(nx, ny) - box:bottomLeft()
		local m = ipe.Translation(trans)
		for j = 1,#p do
			p:transform(j, m)
		end

		local elements={}
		for i,obj,sel,layer in p:objects() do
			elements[#elements+1]=obj
		end

		local group = ipe.Group(elements)
		model:creation("create graph", group)
		break
	end

	-- remove tmp file
	if ipe.fileExists(tmpipe) then
		_G.os.execute("rm " .. tmpipe)
	end
end
