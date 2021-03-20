(local module {})

(lambda module.new-block [x y z]
        {:position (lovr.math.newVec3 x y z)
         :text ""})

(lambda module.add-block [block]
        (table.insert store.blocks block))

module