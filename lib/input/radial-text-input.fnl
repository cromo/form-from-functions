(local {: wrap} (require :lib/math))

(local
 available-input-adapters
 {:oculus-touch
  (fn []
    (let [(x y) (lovr.headset.getAxis :hand/left :thumbstick)
          centered? (and (< -0.001 x 0.001) (< -0.001 y 0.001))
          append-character (lovr.headset.wasPressed :hand/right :a)
          backspace (lovr.headset.wasPressed :hand/right :b)] 
      {: x : y
       : centered?
       : append-character : backspace}))})

(local input-adapter
       (match (lovr.headset.getName)
         "Oculus Quest" available-input-adapters.oculus-touch))

(local module {})

(local default-alphabet " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")

(fn module.init [alphabet]
  {:alphabet (if alphabet alphabet default-alphabet)
   :selected-character " "})

(fn module.update [state dt container]
  (let [{: x : y : centered?
         : append-character : backspace} (input-adapter)
        angle-radians (+ math.pi (math.atan2 y x))
        angle-percent (* (/ angle-radians (* 2 math.pi)) (length state.alphabet))
        character-index-raw (math.ceil angle-percent)
        character-index (if (= 0 character-index-raw) 1 character-index-raw)]
    (set state.selected-character
         (if centered? " "
             (state.alphabet:sub character-index character-index))) 
    (when append-character
      (set container.text (.. container.text state.selected-character))) 
    (when backspace
      (set container.text (container.text:sub 1 -2)))))

(fn module.draw [state]
  ;; Draw the selected character in the center
  (lovr.graphics.print state.selected-character)
  ;; Draw the alphabet around it in a circle
  (let [offset (vec3 -1 0 0)
        alphabet state.alphabet
        character-rotation (quat (/ (* 2 math.pi) (length alphabet)) 0 0 1)]
    (for [i 1 (length alphabet)]
      (lovr.graphics.print (alphabet:sub i i) offset.x offset.y 0 0.25)
      (character-rotation:mul offset))))

module