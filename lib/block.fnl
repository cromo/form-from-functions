(local block {})

(lambda block.new-block [x y z]
        {:position (lovr.math.newVec3 x y z)
         :text ""})

(lambda block.add-block [block]
        (table.insert store.blocks block))

(fn block.draw-block [block]
  (let [(width) (: (lovr.graphics.getFont) :getWidth block.text)]
    (lovr.graphics.box :line block.position (+ 0.1 (* 0.0254 width)) 0.1 0.1))
  (lovr.graphics.print block.text block.position 0.0254)
  (when block.next (lovr.graphics.line block.position block.next.position)))

block