(local {: wrap} (require :lib/math))

(local
 available-input-adapters
 {:oculus-touch
  (fn []
    (let [(x y) (lovr.headset.getAxis :hand/left :thumbstick)
          centered? (and (< -0.001 x 0.001) (< -0.001 y 0.001))
          append-character (lovr.headset.wasPressed :hand/right :a)
          backspace (lovr.headset.wasPressed :hand/right :b)
          next-layer (lovr.headset.wasPressed :hand/left :thumbstick)] 
      {: x : y
       : centered?
       : append-character : backspace
       : next-layer}))})

(local input-adapter
       (match (lovr.headset.getName)
         "Oculus Quest" available-input-adapters.oculus-touch))

(local disk-text-input {})

(local character-layers ["abcdefghijklmnopqrstuvwxyz"
                         "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                         "1234567890-=.,;/'\\[]`"
                         "!@#$%^&*()_+<>:?\"|{}~"])

(fn disk-text-input.init []
  {:selected-character " "
   :layer 1})

(fn disk-text-input.update [state dt container]
  (let [{: x : y : centered?
         : append-character : backspace : next-layer} (input-adapter)
        angle-radians (+ math.pi (math.atan2 y x))
        angle-percent (* (/ angle-radians (* 2 math.pi)) (length (. character-layers state.layer)))
        character-index-raw (math.ceil angle-percent)
        character-index (if (= 0 character-index-raw) 1 character-index-raw)]
    (set state.selected-character
         (if centered? " "
             (: (. character-layers state.layer) :sub character-index character-index))) 
    (when append-character
      (set container.text (.. container.text state.selected-character))) 
    (when backspace
      (set container.text (container.text:sub 1 -2))) 
    (when next-layer
      (set state.layer (wrap (+ 1 state.layer) (length character-layers))))))

(fn disk-text-input.draw [state]
  (lovr.graphics.print state.selected-character 0 0 0 0.05))

disk-text-input