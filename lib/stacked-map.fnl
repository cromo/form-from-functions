;; A stacked-map is a data structure that behaves mostly like a stack, but where
;; each element also has a name. Elements can be popped off the top or by name,
;; and if a pushed element uses the same name as an existing item the old one is
;; removed and the new item is placed on top.

(local module {})

(fn module.new [] {})

(fn module.push [stacked-map key value]
  (match stacked-map
    {key index} (do (module.pop stacked-map key)
                    (module.push stacked-map key value))
    {key nil} (do (table.insert stacked-map [key value])
                  (tset stacked-map key (length stacked-map)))))

(fn module.pop [stacked-map key]
  (when (< 0 (length stacked-map))
    (if key
      (let [index (. stacked-map key)
            [_ value] (. stacked-map index)]
        (table.remove stacked-map index)
        (tset stacked-map key nil)
        value)
      (let [[key _] (. stacked-map (length stacked-map))]
        (module.pop stacked-map key)))))

(fn module.top [stacked-map]
  (match (. stacked-map (length stacked-map))
    [key value] (values value key)
    nil nil))

(fn module.clear [stacked-map]
  (while (< 0 (length stacked-map))
    (module.pop stacked-map)))

module