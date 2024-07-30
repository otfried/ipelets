----------------------------------------------------------------------
-- moviemaker ipelet
----------------------------------------------------------------------

label = "Movie maker"

function next_step(model)
  local t = { label="next step: copy current layer into new view",
	      pno = model.pno,
	      vno0 = model.vno,
	      vno1 = model.vno + 1,
	      original = model:page():clone(),
	      undo = _G.revertOriginal,
  }
  t.redo = function (t, doc)
    local p = doc[t.pno]
    local active = p:active(t.vno0)
    p:insertView(t.vno1, active)
    for i,layer in ipairs(p:layers()) do
      p:setVisible(t.vno1, layer, p:visible(t.vno0, layer))
    end
    local newLayer = doc[t.pno]:addLayer()
    p:setVisible(t.vno1, newLayer, true)
    p:setActive(t.vno1, newLayer)
    p:setVisible(t.vno1, active, false)
    for i, obj, sel, layer in p:objects() do
      if layer == active then
	p:setSelect(i, nil)
	p:insert(nil, obj:clone(), nil, newLayer)
      end
    end
  end
  model:register(t)
  model:nextView(1)
  model:setPage()
end

methods = {
  { label = "Next step", run=next_step },
}

shortcuts.ipelet_1_moviemaker = "Ctrl+Shift+J"

----------------------------------------------------------------------
