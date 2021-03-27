(local {: wrap} (require :lib/math))

(local disk-text-input {})

(local character-layers ["abcdefghijklmnopqrstuvwxyz"
                         "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                         "1234567890-=.,;/'\\[]`"
                         "!@#$%^&*()_+<>:?\"|{}~"])

(fn disk-text-input.init []
  {:selected-character " "
   :layer 1})

(fn disk-text-input.update [state container]
  (let [(x y) (lovr.headset.getAxis :hand/left :thumbstick)
        centered? (and (< -0.001 x 0.001) (< -0.001 y 0.001))
        angle-radians (+ math.pi (math.atan2 y x))
        angle-percent (* (/ angle-radians (* 2 math.pi)) (length (. character-layers state.layer)))
        character-index-raw (math.ceil angle-percent)
        character-index (if (= 0 character-index-raw) 1 character-index-raw)]
    (set state.selected-character
         (if centered? " "
             (: (. character-layers state.layer) :sub character-index character-index))))
  (when (lovr.headset.wasPressed :hand/right :a)
    (set container.text (.. container.text state.selected-character)))
  (when (lovr.headset.wasPressed :hand/right :b)
    (set container.text (container.text:sub 1 -2)))
  (when (lovr.headset.wasPressed :hand/left :thumbstick)
    (set state.layer (wrap (+ 1 state.layer) (length character-layers)))))

(fn disk-text-input.draw [state]
  (lovr.graphics.print state.selected-character 0 1 -0.5 0.05))

disk-text-input