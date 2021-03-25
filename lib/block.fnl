(local module {})

(lambda module.new-block [x y z]
        {:position (lovr.math.newVec3 x y z)
         :text ""})

(lambda module.add-block [block]
        (table.insert store.blocks block))

(fn module.draw-block [block]
  (lovr.graphics.box :line block.position 0.1 0.1 0.1)
  (lovr.graphics.print block.text block.position 0.0254)
  (when block.next (lovr.graphics.line block.position block.next.position)))

module