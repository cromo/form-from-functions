(local breaker-stack (require "lib/adapters/non-empty-breaker-stack"))

(T "A non-empty breaker stack"
   (fn [T]
     (T "when created"
        (fn [T]
          (T "with extra aguments should pass them through to the default layer"
             (fn [T]
               (var arg nil)
               (breaker-stack.init {:init #(set arg $)} nil "hi")
               (T:assert (= arg "hi"))))))
     (T "should pass callbacks through to the default layer when there's nothing on the stack"
        (fn [T]
          (var call-count 0)
          (let [stack (breaker-stack.init {:draw #(set call-count (+ 1 call-count))})]
            (breaker-stack.draw stack))
          (T:assert (= call-count 1) (.. "Expected call-count to be 1 but was " call-count))))
     (T "when there's a layer on the stack"
        (fn [T]
          (T "should pass callbacks to top of the stack and to nothing else"
             (fn [T]
               (var default-count 0)
               (var stack-bottom-count 0)
               (var stack-top-count 0)
               (let [stack (breaker-stack.init {:update #(set default-count (+ 1 default-count))})]
                 (doto stack
                   (breaker-stack.push :bottom {:update #(set stack-bottom-count (+ 1 stack-bottom-count))})
                   (breaker-stack.push :top {:update #(set stack-top-count (+ 1 stack-top-count))})
                   (breaker-stack.update)))
               (T:assert (and (= default-count 0)
                              (= stack-bottom-count 0)
                              (= stack-top-count 1)))))
          (T "and it errors"
             (fn [T]
               (T "then the top layer should be popped off"
                  (fn [T]
                    (var default-count 0)
                    (let [stack (breaker-stack.init {:draw #(set default-count (+ 1 default-count))})]
                      (breaker-stack.push stack :error {:draw #(error "Failed")})
                      (breaker-stack.draw stack)
                      (T:assert (= default-count 0) "but the default update was called")
                      (breaker-stack.draw stack)
                      (T:assert (= default-count 1) "but it didn't default to the previous layer"))))
               (T "it should call the provided error handler"
                  (fn [T]
                    (var callback-count 0)
                    (doto (breaker-stack.init {} #(set callback-count 1))
                      (breaker-stack.push :error {:update #(error "Failed")})
                      (breaker-stack.update))
                    (T:assert (= callback-count 1) "but it wasn't called")))))))))