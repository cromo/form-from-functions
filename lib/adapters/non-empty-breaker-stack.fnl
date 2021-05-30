(local sm (require :lib/stacked-map))
(local breaker (require :lib/adapters/breaker))

(local module {})

(fn module.init [default on-fault ...]
  (let [{: init} default]
    {:default-state (when init (init ...))
     :default-callbacks default
     :stack (sm.new)
     : on-fault}))

(fn module.push [{: stack : on-fault} name layer ...]
  (sm.push stack name
           (breaker.init layer
                         #(do (sm.pop stack name)
                              (when on-fault (on-fault name $...)))
                         ...)))

(fn module.pop [{: stack} name]
  (sm.pop stack name))

(fn module.clear [{: stack}]
  (sm.clear stack))

(fn call-through [self callback-name ...]
  (if (< 0 (length self.stack))
    ((. breaker callback-name) (sm.top self.stack) ...)
    (match self.default-callbacks
      {callback-name callback} (callback self.default-state ...))))

(fn module.update [self ...]
  (call-through self :update ...))

(fn module.draw [self ...]
  (call-through self :draw ...))

module