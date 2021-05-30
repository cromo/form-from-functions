(local log (require :lib/logging))

(local module {})

(fn module.init [detector callback]
  #(when (detector $...) (callback)))

(fn module.update [self ...]
  (self ...))

module