(local log (require :lib/logging))
(local block {})

(local inch 0.0254)

(lambda block.init [x y z]
        {:position (lovr.math.newVec3 x y z)
         :rotation (lovr.math.newQuat)
         :text ""})

(fn block.link [from to]
  (set from.next (if from.next nil to)))

(fn draw-link [block]
  (let [font (lovr.graphics.getFont)
        (unscaled-width) (font:getWidth block.text)
        width (* inch unscaled-width)
        next block.next
        (next-unscaled-width) (font:getWidth next.text)
        next-width (* inch next-unscaled-width)
        start-offset (vec3 (* 0.5 (+ 0.03 width)) 0 0)
        end-offset (vec3 (* 0.5 (+ 0.03 next-width)) 0 0)]
    (block.rotation:mul start-offset)
    (next.rotation:mul end-offset)
    (lovr.graphics.line
     (+ block.position start-offset)
     (- next.position end-offset))))

(fn block.draw-box [block color]
  (let [font (lovr.graphics.getFont)
        (unscaled-width) (font:getWidth block.text)
        width (* inch unscaled-width)
        (x y z) (block.position:unpack)
        color (or color [1 1 1])]
    (lovr.graphics.setColor color)
    (lovr.graphics.box :line
                       x y z
                       (+ 0.03 width) 0.03 0.03
                       (block.rotation:unpack))))

(fn block.draw-text [block]
  (local (x y z) (block.position:unpack))
  (lovr.graphics.print block.text x y z inch block.rotation))

(fn block.draw-link [block]
  (when block.next (draw-link block)))

(local mod-draw-box block.draw-box)
(local mod-draw-text block.draw-text)
(local mod-draw-link block.draw-link)

(fn block.draw [block]
  (mod-draw-box block)
  (mod-draw-text block)
  (mod-draw-link block))

block