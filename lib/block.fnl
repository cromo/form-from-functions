(local block {})

(lambda block.new-block [x y z]
        {:position (lovr.math.newVec3 x y z)
         :text ""})

(lambda block.add-block [block]
        (table.insert store.blocks block))

(fn block.draw-block [block]
  (let [font (lovr.graphics.getFont)
        (unscaled-width) (font:getWidth block.text)
        inch 0.0254
        width (* inch unscaled-width)]
    (lovr.graphics.box :line block.position (+ 0.1 width) 0.1 0.1)
    (lovr.graphics.print block.text block.position inch)
    (when block.next
      (let [next block.next
            (next-unscaled-width) (font:getWidth next.text)
            next-width (* inch next-unscaled-width)]
        (lovr.graphics.line
         (+ block.position (vec3 (* 0.5 (+ 0.1 width)) 0 0))
         (- next.position (vec3 (* 0.5 (+ 0.1 next-width)) 0 0)))))))

block