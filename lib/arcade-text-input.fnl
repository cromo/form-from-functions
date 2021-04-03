(local d-pad (require :lib/virtual-d-pad))
(local {: wrap} (require :lib/math))

(local arcade-text-input {})

(local character-list " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")

(fn arcade-text-input.init []
  {:text-index 1
   :d-pad (d-pad.init :hand/left)})

(fn arcade-text-input.update [state container]
  (d-pad.update state.d-pad)
  (when (lovr.headset.wasPressed :hand/right :a)
    (set container.text (.. container.text (character-list:sub state.text-index state.text-index))))
  (when (lovr.headset.wasPressed :hand/right :b)
    (set container.text (container.text:sub 1 -2)))
  (when (d-pad.d-pad-was-pressed-or-repeated state.d-pad :down)
    (set state.text-index (wrap (+ 1 state.text-index) (length character-list))))
  (when (d-pad.d-pad-was-pressed-or-repeated state.d-pad :up)
    (set state.text-index (wrap (- state.text-index 1) (length character-list)))))

(fn arcade-text-input.draw [state]
  (lovr.graphics.print (character-list:sub state.text-index state.text-index) 0 1 -0.5 0.05))

arcade-text-input