;; Breakers protect the calling layers in the case that the wrapped layer (the
;; circuit) errors. It does so by catching the error and marking the code as no
;; longer running so that it doesn't call its callbacks anymore.
(local breaker {})

(fn breaker.init [circuit on-fault ...]
  {:circuit-state (when circuit.init (circuit.init ...))
   :circuit-callbacks circuit
   :running true
   : on-fault})

(fn fault [breaker error-message]
  (set breaker.running false)
  (when breaker.on-fault (breaker.on-fault error-message)))

(fn call-through [breaker callback-name ...]
  (when (and breaker.running (. breaker.circuit-callbacks callback-name))
    (xpcall (. breaker.circuit-callbacks callback-name)
            #(fault breaker $1)
            breaker.circuit-state
            ...)))

(fn breaker.update [self ...]
  (call-through self :update ...))

(fn breaker.draw [self ...]
  (call-through self :draw ...))

breaker