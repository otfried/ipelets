----------------------------------------------------------------------
-- Tangent Lines ipelet
----------------------------------------------------------------------
--[[

   The Tangent Lines ipelet is free software; you can redistribute it
   and/or modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 3 of
   the License, or (at your option) any later version.

   It is distributed in the hope that it will be useful, but WITHOUT
   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
   or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
   License for more details.

   You should have received a copy of the GNU General Public License
   along with Ipe; if not, you can find it at
   "http://www.gnu.org/copyleft/gpl.html", or write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

--]]

--[[
   TODO: make ipelet work with
     - arcs
     - splines
--]]

label = "Tangent Lines"

about = [[
Draws tangent segments from a primary selected marker/circle/ellipse to all
other selected markers, circles and ellipses.
By Andrew Martchenko
]]

function unit_circ_to_circ_intersect(x1,y1,r1)
   local dc = math.sqrt(x1*x1 + y1*y1)      -- distance between centers
   local A = (dc*dc + r1*r1 - 1)/(2*dc)    
   local B = math.sqrt(r1*r1 - A*A)
   local p1 = ipe.Vector(x1 - (x1*A + y1*B)/dc,
			 y1 - (y1*A - x1*B)/dc)
   --OR					   
   local p2 = ipe.Vector(x1 - (x1*A - y1*B)/dc,
			 y1 - (y1*A + x1*B)/dc)
   return p1, p2
end

function create_objects(model, objects)

   if #objects>0 then
      local t = { label="tangent segments", 
		  pno=model.pno, 
		  vno=model.vno, 
		  layer=model:page():active(model.vno), 
		  objects=objects
      }
      t.undo = function (t, doc) 
	 for i = 1,#t.objects do
	    doc[t.pno]:remove(#doc[t.pno]) 
	 end
      end
      t.redo = function (t, doc) 
	 doc[t.pno]:deselectAll()
	 for _,obj in ipairs(t.objects) do
	    doc[t.pno]:insert(nil, obj.obj, obj.select, t.layer) 
	 end
	 doc[t.pno]:ensurePrimarySelection()
      end
      model:register(t)
   end
end

function make_segment(model, p1, p2)
   local shape = {type="curve", closed=false;
		  {type="segment"; p1, p2}}
   return ipe.Path(model.attributes, {shape} )
end

function circle_radius(mat)
   local e = mat:elements()
   return math.sqrt(e[1]*e[1]+e[2]*e[2])
end

function get_object_type(obj)
   if obj:type()=="path" then
      if obj:shape()[1].type == "ellipse" then
	 local matrix = obj:matrix()*obj:shape()[1][1]
	    return {type="ellipse", matrix=matrix}
      else
	 return {type=nil, matrix=nil}
      end
   elseif obj:type()=="reference" then
      return {type="reference", vector=obj:matrix()*obj:position()}
   end
end


function unit_circ_to_mark_tangent_points(m)

   local r = 1
   if r==0 then return c,c end
   -- local d = c-m
   local ll = m:sqLen()
   if(ll<=1) then return end -- there are no tagent lines in this case
   
   local r2 = math.sqrt(ll - 1)

   return unit_circ_to_circ_intersect(m.x, m.y, r2)
end


function ellipse_to_mark_tangent_points(m, e)
   local p=e:inverse()*m; -- undo affine transformations
   local p1,p2 = unit_circ_to_mark_tangent_points(p)
   -- redo affine transformation
   if p1 then -- if tangent points exist
      return e*p1, e*p2
   else
      return
   end
end

function ellipse_to_mark_tangent_segments(model, m, e)
   local p1,p2 = ellipse_to_mark_tangent_points(m, e)
   local segs = {}
   segs[1] = { obj=make_segment(model, m, p1), select = nil }
   segs[2] = { obj=make_segment(model, m, p2), select = nil }
   return segs
end

function length(a,b)
   return math.sqrt((a.x-b.x)*(a.x-b.x) + (a.y-b.y)*(a.y-b.y))
end


function max_dist(e1,c)
   local pa, pb, a
   local t=math.pi/2

   local p = ellipse_point_at_angle(e1,0)

   a=0
   for i=1,10 do
      pa = ellipse_point_at_angle(e1,a+t)
      pb = ellipse_point_at_angle(e1,a-t)
      if length(pa,c)>length(pb,c) then
	 p=pa
	 a=a+t
      else
	 p=pb
	 a=a-t
      end
      t=t/2;
   end

   return p
end

-- takes two ellipses and sorts them by length
function sort_by_length(e1,e2)
   local s1a,s1b,s2a,s2b

   -- find the length of the major axis
   s1a = ipe.Vector(e1:elements()[1],e1:elements()[2]):len()
   s1b = ipe.Vector(e1:elements()[3],e1:elements()[4]):len()
   s2a = ipe.Vector(e2:elements()[1],e2:elements()[2]):len()
   s2b = ipe.Vector(e2:elements()[3],e2:elements()[4]):len()

   -- find the largest major axis
   if s1a<s1b then s1a=s1b end
   if s2a<s2b then s2a=s2b end
   if s1a<s2a then return e2,e1 else return e1, e2 end -- swap if largest is not e1

end

function count_nils(t)
   local c=0
   for i=1,4 do
      if t[i]==nil then c=c+1 end
   end
   return c
end

function ellipse_to_ellipse_tangent_segments(model, e1, e2)
   local p1, p2 = {},{}
   local p1a,p1b,p2a,p2b = {},{},{},{}


   -- TODO
   -- if intersecting then
   --     find intersections
   --     use points close to intersections to start the searching process.
   -- end
   

   -- find the longer ellipse then make it e1
   e1,e2 = sort_by_length(e1,e2)
   -- find the most distant point on e1 from the center of e2
   p1[1] = max_dist(e1,e2:translation())
   -- from p1a find tangent points to e2, call these points p2[1] and p2[2]
   p2[1],p2[2] = ellipse_to_mark_tangent_points(p1[1],e2)
   -- from p2[1] and p2[2] find tangent points to e1, call them p1[1], p1[2], p1[3] and p1[4]
   p1[1],p1[3] = ellipse_to_mark_tangent_points(p2[1],e1)
   p1[2],p1[4] = ellipse_to_mark_tangent_points(p2[2],e1)

   -- if no tangents found, try swapping the ellipses
   if count_nils(p1)>0 then
      -- swap e1 and e2
      e1,e2 = e2,e1
      -- find the most distant point on e1 from the center of e2
      p1[1] = max_dist(e1,e2:translation())
      -- from p1a find tangent points to e2, call these points p2[1] and p2[2]
      p2[1],p2[2] = ellipse_to_mark_tangent_points(p1[1],e2)
      -- from p2[1] and p2[2] find tangent points to e1, call them p1[1], p1[2], p1[3] and p1[4]
      p1[1],p1[3] = ellipse_to_mark_tangent_points(p2[1],e1)
      p1[2],p1[4] = ellipse_to_mark_tangent_points(p2[2],e1)
   end

   p2[3], p2[4] = p2[1], p2[2]

   
   -- from all p1[x] points find tangent point to e2, call them p2[x] and keep only the ones that are closest to the old p2[x] points
   -- repeat last step until convergence.

   for i=1,10 do 

      for j=1,4 do -- for all four possible tangent points

	 -- if p1[j] exists, then generate possible tangent points to e2
	 if p1[j] then p2a[j],p2b[j] = ellipse_to_mark_tangent_points(p1[j], e2) end

	 -- if generated tangent points exist
   	 if p2a[j] then
	    -- find the closest one to the previouse value of p2[j] and set it to p2[j]
	    if length(p2[j], p2a[j]) < length(p2[j], p2b[j]) then p2[j] = p2a[j] else p2[j] = p2b[j] end
	 else
	    p2[j]=nil
	 end

	 -- repeate abve steps, but form the point of view of the other ellipse
	 if p2[j] then p1a[j],p1b[j] = ellipse_to_mark_tangent_points(p2[j], e1) end

      	 if p1a[j] then
	    if length(p1[j], p1a[j]) < length(p1[j], p1b[j]) then p1[j] = p1a[j] else p1[j] = p1b[j] end
	 else
	    p1[j]=nil
	 end
      end

   end


   -- make the segments
   local segs={} -- these will be the segment objects for drawing
   local s={} -- these are the segments for finding intersect
   for i=1,4 do
      if p1[i] and p2[i] then
	 s[#s+1] = ipe.Segment(p1[i],p2[i])
	 segs[#segs+1] = { obj = make_segment(model,p1[i], p2[i]), select = nil }		  
      end
   end

   -- if only two segments, then there cannot be andy intersects
   if #s==2 then return segs end

   -- else search intersecting segments and return
   local s1,s2
   for i=1,#s do
      for j=i,#s do
	 if s[i]:intersects(s[j]) then
	    segs[i].select = 2
	    segs[j].select = 2
	    return segs
	 end
      end
   end

   return segs
end


function ellipse_point_at_angle(e,t)
   return e*ipe.Vector(math.cos(t), math.sin(t))
end


function print_selection_warning(model)
   model:warning("Must select either:\nA marker and circle\nOR\nTwo circles")
end

function table_concat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end

function run(model)

   local page = model:page()
   local prim = page:primarySelection()
   if not prim then print_selection_warning(model) return end
   local obj = page[prim]
   local p,s
   
   p = get_object_type(obj)

   local segs = {}
   local segments={}


   for i, obj, sel, layer in page:objects() do

      segs={}
      
      if sel and i~=prim then

	 s = get_object_type(obj)

	 if p.type=="reference" then
	    
	    if s.type=="reference" then
	       segs[1] = { obj = make_segment(model, p.vector, s.vector), select=nil}
	    elseif s.type=="ellipse" then
	       segs = ellipse_to_mark_tangent_segments(model, p.vector,s.matrix)
	    end
	    
	 elseif p.type=="ellipse" then
	    
	    if s.type=="reference" then
	       segs = ellipse_to_mark_tangent_segments(model, s.vector,p.matrix)
	    elseif s.type=="ellipse" then
	       segs = ellipse_to_ellipse_tangent_segments(model, p.matrix, s.matrix)
	    end
	    
	 end

      end
      segments = table_concat(segments,segs)
   end

   create_objects(model, segments)
   
end

shortcuts.ipelet_1_tangentlines = "Alt+t"
