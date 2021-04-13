;; A binder attaches a layer's callbacks to its state, making it behave more
;; like traditional objects. The resulting object should have its functions
;; called via `:`, much like any other "object" in Lua.
(local binder {})

(fn binder.init [layer ...]
  (let [proxy {}
        state (when (and layer layer.init) (layer.init ...))
        metatable {:__index
                   (fn [self key]
                     (let [value (. layer key)]
                       (if (= (type value) :function)
                         ;; Skip the "self" on the call because it's the empty
                         ;; proxy object.
                         #(value state (select 2 $...))
                         value)))}]
    (setmetatable proxy metatable)
    proxy))

binder