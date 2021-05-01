(local log (require :lib/logging))
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
        width (* inch unscaled-width)
        (x y z) (block.position:unpack)]
    (lovr.graphics.box :line
                       x y z
                       (+ 0.03 width) 0.03 0.03
                       (block.rotation:unpack))
    (lovr.graphics.print block.text x y z inch block.rotation)
    (when block.next
      (let [next block.next
            (next-unscaled-width) (font:getWidth next.text)
            next-width (* inch next-unscaled-width)]
        (lovr.graphics.line
         (+ block.position (vec3 (* 0.5 (+ 0.03 width)) 0 0))
         (- next.position (vec3 (* 0.5 (+ 0.03 next-width)) 0 0)))))))

block