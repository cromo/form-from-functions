(local disk-text-input {})

(local character-list " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")

(fn disk-text-input.new-text-input []
  {:selected-character " "})

(fn disk-text-input.update-text-input [state container]
  (let [(x y) (lovr.headset.getAxis :hand/left :thumbstick)
        centered? (and (< -0.001 x 0.001) (< -0.001 y 0.001))
        angle-radians (+ math.pi (math.atan2 y x))
        angle-percent (* (/ angle-radians (* 2 math.pi)) (length character-list))
        character-index-raw (math.ceil angle-percent)
        character-index (if (= 0 character-index-raw) 1 character-index-raw)]
    (set state.selected-character
         (if centered? " "
             (character-list:sub character-index character-index))))
  (when (lovr.headset.wasPressed :hand/right :a)
    (set container.text (.. container.text state.selected-character)))
  (when (lovr.headset.wasPressed :hand/right :b)
    (set container.text (container.text:sub 1 -2))))

(fn disk-text-input.draw-text-input [state]
  (lovr.graphics.print state.selected-character 0 1 -0.5 0.05))

disk-text-input