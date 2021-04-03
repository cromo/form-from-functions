(local block {})

(lambda block.init [x y z]
        {:position (lovr.math.newVec3 x y z)
         :rotation (lovr.math.newQuat)
         :text ""})

(fn block.link [from to]
  (set from.next (if from.next nil to)))

(fn block.draw [block]
  (let [font (lovr.graphics.getFont)
        (unscaled-width) (font:getWidth block.text)
        inch 0.0254
        width (* inch unscaled-width)]
    (lovr.graphics.box :line block.position (+ 0.03 width) 0.03 0.03 block.rotation)
    (lovr.graphics.print block.text block.position inch block.rotation)
    (when block.next
      (let [next block.next
            (next-unscaled-width) (font:getWidth next.text)
            next-width (* inch next-unscaled-width)]
        (lovr.graphics.line
         (+ block.position (vec3 (* 0.5 (+ 0.03 width)) 0 0))
         (- next.position (vec3 (* 0.5 (+ 0.03 next-width)) 0 0)))))))

block