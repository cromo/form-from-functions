(local module {})

(fn module.wrap [index size]
  (+ 1 (% (- index 1) size)))

module