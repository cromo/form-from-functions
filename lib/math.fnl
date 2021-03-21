;; This one is named module because math is a built-in module that this code may
;; need to reference.
(local module {})

(fn module.wrap [index size]
  (+ 1 (% (- index 1) size)))

(lambda module.format-vec2 [vec]
        (string.format "(vec2 %.2f, %.2f)" (vec:unpack)))

(lambda module.format-vec3 [vec]
        (string.format "(vec3 %.2f, %.2f, %.2f)" (vec:unpack)))

module