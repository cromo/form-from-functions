(local breaker (require :lib/breaker))
(local log (require :lib/logging))

(local logging-breaker {:update breaker.update :draw breaker.draw})

(fn logging-breaker.init [circuit ...]
  (breaker.init
   circuit
   #(log.error :breaker (debug.traceback (tostring $1)))
   ...))

logging-breaker