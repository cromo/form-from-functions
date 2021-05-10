(local selector (require "lib/adapters/selector"))
(local radial-input (require "lib/input/radial-text-input"))

(local
 available-input-adapters
 {:oculus-touch
  (fn []
    {:next-layer (lovr.headset.wasPressed :hand/left :thumbstick)})})

(local input-adapter
       (match (lovr.headset.getName)
         "Oculus Quest" available-input-adapters.oculus-touch))

(local module {})

(local default-layers ["abcdefghijklmnopqrstuvwxyz"
                       "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                       "1234567890-=.,;/'\\[]`"
                       "!@#$%^&*()_+<>:?\"|{}~"])

(fn module.init [layers]
  (local selector-args [])
  (let [layers (if layers layers default-layers)]
    (each [_ layer (ipairs layers)]
          (table.insert selector-args radial-input)
          (table.insert selector-args [layer])))
  {:selector (selector.init (unpack selector-args))})

(fn module.update [self dt container]
  (match (input-adapter)
    {:next-layer true} (selector.select-next self.selector))
  (selector.update self.selector dt container))

(fn module.draw [self]
  (selector.draw self.selector))

module