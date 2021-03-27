(local {: d-pad-was-pressed-or-repeated} (require :lib/input))
(local {: wrap} (require :lib/math))

(local arcade-text-input {})

(local character-list " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")

(fn arcade-text-input.new-text-input []
  {:text-index 1})

(fn arcade-text-input.update-text-input [state container]
  (let [{: input} store] 
    (when (lovr.headset.wasPressed :hand/right :a)
      (set container.text (.. container.text (character-list:sub state.text-index state.text-index)))) 
    (when (lovr.headset.wasPressed :hand/right :b)
      (set container.text (container.text:sub 1 -2))) 
    (when (d-pad-was-pressed-or-repeated :hand/left :down)
      (set state.text-index (wrap (+ 1 state.text-index) (length character-list)))) 
    (when (d-pad-was-pressed-or-repeated :hand/left :up)
      (set state.text-index (wrap (- state.text-index 1) (length character-list))))))

(fn arcade-text-input.draw-text-input [state]
  (lovr.graphics.print (character-list:sub state.text-index state.text-index) 0 1 -0.5 0.05))

arcade-text-input