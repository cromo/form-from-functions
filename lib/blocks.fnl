(local block (require :lib/block))
(local json (require :cjson))

(local blocks {})

(fn blocks.init []
  [])

(fn blocks.add [self block]
  (table.insert self block))

(fn blocks.draw [self]
  (each [i block-state (ipairs self)]
        (block.draw block-state)))

(fn find-first [value t]
  (var index 0)
  (var found? false)
  (while (and (< index (length t)) (not found?))
    (set index (+ 1 index))
    (when (= value (. t index))
      (set found? true)))
  (if found? index nil))

(fn blocks.serialize [blocks]
  (json.encode (icollect [_ block (ipairs blocks)]
                         {:position [(block.position:unpack)]
                          :rotation [(block.rotation:unpack)]
                          :text block.text
                          :next (find-first block.next blocks)})))

(fn blocks.deserialize [encoded-blocks]
  (let [blocks (json.decode encoded-blocks)]
    (each [_ block (ipairs blocks)]
          (set block.position (lovr.math.newVec3 (unpack block.position)))
          (set block.rotation (lovr.math.newQuat (unpack block.rotation)))
          (when block.next
            (set block.next (. blocks block.next))))
    blocks))

blocks