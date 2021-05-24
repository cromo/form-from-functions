(local log (require :lib/logging))
(local block {})

(local inch 0.0254)

(lambda block.init [x y z]
        {:position (lovr.math.newVec3 x y z)
         :rotation (lovr.math.newQuat)
         :text ""
         :type :plain-text})

(fn block.link [from to]
  (set from.next (if (= from to) nil to)))

(fn block.link-contents [from to]
  (set from.contents (if (= from to) nil to)))

(fn block.become-next-type [block]
  (match [block.type block.prefix]
    [:plain-text _] (do (set block.type :container)
                        (set block.prefix "(")
                        (set block.suffix ")")
                        (set block.text "(...)"))
    [:container "("] (do (set block.type :container)
                         (set block.prefix "[")
                         (set block.suffix "]")
                         (set block.text "[...]"))
    [:container "["] (do (set block.type :container)
                         (set block.prefix "{")
                         (set block.suffix "}")
                         (set block.text "{...}"))
    [:container "{"] (do (set block.type :plain-text)
                         (set block.prefix nil)
                         (set block.suffix nil)
                         (set block.text "")
                         (set block.contents nil))))

(fn draw-link [block kind]
  (let [kind (if kind kind :text)
        font (lovr.graphics.getFont)
        (unscaled-width) (font:getWidth block.text)
        width (* inch unscaled-width)
        next (match kind
               :text block.next
               :contents block.contents)
        (next-unscaled-width) (font:getWidth next.text)
        next-width (* inch next-unscaled-width)
        start-offset (vec3 (* 0.5 (+ 0.03 width)) 0 0)
        end-offset (vec3 (* 0.5 (+ 0.03 next-width)) 0 0)
        color (match kind
                :text :0xffffff
                :contents :0x00ffff)]
    (block.rotation:mul start-offset)
    (next.rotation:mul end-offset)
    (lovr.graphics.setColor color)
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
  (lovr.graphics.setColor :0xffffff)
  (lovr.graphics.print block.text x y z inch block.rotation))

(fn block.draw-link [block]
  (when block.next (draw-link block))
  (when block.contents (draw-link block :contents)))

(local mod-draw-box block.draw-box)
(local mod-draw-text block.draw-text)
(local mod-draw-link block.draw-link)

(fn block.draw [block]
  (mod-draw-box block)
  (mod-draw-text block)
  (mod-draw-link block))

block