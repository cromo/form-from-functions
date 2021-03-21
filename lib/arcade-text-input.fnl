(local {: d-pad-was-pressed-or-repeated} (require :lib/input))
(local {: wrap} (require :lib/math))

(local arcade-text-input {})

(fn arcade-text-input.update-text-input [container]
  (let [{: input :config {: character-list}} store] 
    (when (lovr.headset.wasPressed :hand/right :a)
      (set container.text (.. container.text (character-list:sub input.text-index input.text-index)))) 
    (when (lovr.headset.wasPressed :hand/right :b)
      (set container.text (container.text:sub 1 -2))) 
    (when (d-pad-was-pressed-or-repeated :hand/left :down)
      (set input.text-index (wrap (+ 1 input.text-index) (length character-list)))) 
    (when (d-pad-was-pressed-or-repeated :hand/left :up)
      (set input.text-index (wrap (- input.text-index 1) (length character-list))))))

arcade-text-input