(local sm (require :lib/stacked-map))
(local breaker (require :lib/adapters/breaker))

(local module {})

(fn module.init [default ...]
  {:default-state (when (and default default.init) (default.init ...))
   :default-callbacks default
   :stack (sm.new)})

(fn module.push [{: stack} name layer ...]
  (sm.push stack name (breaker.init layer #(sm.pop stack name) ...)))

(fn module.pop [{: stack} name]
  (sm.pop stack name))

(fn call-through [self callback-name ...]
  (if (< 0 (length self.stack))
    ((. breaker :callback-name) (sm.top self.stack) ...)
    (match self.default-callbacks
      {callback-name callback} (callback self.default-state ...))))

(fn module.update [self ...]
  (call-through self :update ...))

(fn module.draw [self ...]
  (call-through self :update ...))

module