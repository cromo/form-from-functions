(local block (require :lib/block))
(local json (require :third-party/dkjson))

(local blocks {})

(fn find-first [value t]
  (var index 0)
  (var found? false)
  (while (and (< index (length t)) (not found?))
    (set index (+ 1 index))
    (when (= value (. t index))
      (set found? true)))
  (if found? index nil))

(fn blocks.init []
  [])

(fn blocks.add [self block]
  (table.insert self block))

(fn blocks.remove [self block-to-remove]
  (each [_ block (ipairs self)]
        (when (= block.next block-to-remove)
          (set block.next nil)))
  (let [index (find-first block-to-remove self)]
    (when index (table.remove self index))))

(fn blocks.draw [self]
  ;; Draw each kind of object separately to help LOVR's batching. Failure to do
  ;; so can lead to excessive draw calls and shader switches, which can tank
  ;; framerate.
  (each [_ block-state (ipairs self)]
        (block.draw-box block-state))
  (each [_ block-state (ipairs self)]
        (block.draw-link block-state))
  (each [_ block-state (ipairs self)]
        (block.draw-text block-state)))

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