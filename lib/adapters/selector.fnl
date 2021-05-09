;; A selector holds multiple layers together, passing all callbacks to only one
;; of the layers. The layer that gets the callbacks can be selected through a
;; few functions.
;; As an example - simple text input layers could handle a subset of all
;; characters, and a selector could be used to choose between layers that
;; handle different characters. In this way, layered input can be achieved while
;; maintaining the simplicity of an individual layer implementation.
(local {: wrap} (require :lib/math))

(local module {})

(fn module.init [...]
  (let [layers-and-args [...]
        ;; Gather the layers and their args so they're easy to zip over
        layers (icollect [i v (ipairs layers-and-args)] (when (= (% i 2) 1) v))
        args (icollect [i v (ipairs layers-and-args)] (when (= (% i 2) 0) v))
        ;; Compatibity between LuaJIT and Lua 5.4 (used for tests)
        do-unpack (if table.unpack table.unpack unpack)
        states (icollect [i layer (ipairs layers)]
                         (match (. args i)
                           nil (layer.init)
                           layer-args (layer.init (do-unpack layer-args))))
        layer-state-pairs (icollect [i layer (ipairs layers)]
                                    [layer (. states i)])]
    {:selected 1
     :layers layer-state-pairs}))

(fn call-through [self callback-name ...]
  (let [[layer state] (. self.layers self.selected)
        callback (. layer callback-name)]
    (when callback (callback state ...))))

(fn module.update [self ...]
  (call-through self :update ...))

(fn module.draw [self ...]
  (call-through self :draw ...))

(fn module.select [self layer]
  (let [new-layer (wrap layer (length self.layers))]
    (set self.selected new-layer)))

(fn module.select-next [self]
  (module.select self (+ 1 self.selected)))

(fn module.select-previous [self]
  (module.select self (- self.selected 1)))

module