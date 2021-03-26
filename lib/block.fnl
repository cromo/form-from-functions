(local json (require :cjson))

(local block {})

(lambda block.new-block [x y z]
        {:position (lovr.math.newVec3 x y z)
         :rotation (lovr.math.newQuat)
         :text ""})

(lambda block.add-block [block]
        (table.insert store.blocks block))

(fn block.draw-block [block]
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

(fn find-first [value t]
  (var index 0)
  (var found? false)
  (while (and (< index (length t)) (not found?))
    (set index (+ 1 index))
    (when (= value (. t index))
      (set found? true)))
  (if found? index nil))

(fn block.serialize-blocks [blocks]
  (json.encode (icollect [_ block (ipairs blocks)]
                         {:position [(block.position:unpack)]
                          :rotation [(block.rotation:unpack)]
                          :text block.text
                          :next (find-first block.next blocks)})))

(fn block.deserialize-blocks [encoded-blocks]
  (let [blocks (json.decode encoded-blocks)]
    (each [_ block (ipairs blocks)]
          (set block.position (lovr.math.newVec3 (unpack block.position)))
          (set block.rotation (lovr.math.newQuat (unpack block.rotation)))
          (when block.next
            (set block.next (. blocks block.next))))
    blocks))

block