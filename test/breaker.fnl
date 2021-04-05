(local breaker (require :lib/breaker))

(T "A breaker layer"
   (fn [T]
     (T "when created"
        (fn [T]
          (T "with extra arguments"
             (fn [T]
               (var arg nil)
               (let [wrappee {:init #(set arg $1)}
                     wrapper (breaker.init wrappee nil 42)]
                 (T:assert (= arg 42) "should pass through extra arguments"))))
          (T "without an init function"
             (fn [T]
               (let [wrapper (breaker.init {})]
                 (T:assert wrapper "shouldn't crash"))))
          (T "with a nil circuit"
             (fn [T]
               (local wrapper (breaker.init nil))
               (T:assert wrapper "shouldn't crash")))))
     (T "in normal operation"
        (fn [T]
          (T "when calling draw without extra arguments"
             (fn [T]
               (var call-count 0)
               (let [wrappee {:init #nil :draw #(set call-count (+ 1 call-count))}
                     wrapper (breaker.init wrappee)]
                 (breaker.draw wrapper)
                 (T:assert (= call-count 1) "should call the wrapped draw")
                 (breaker.draw wrapper)
                 (T:assert (= call-count 2) "should call the wrapped draw every time"))))
          (T "when calling draw that needs state"
             (fn [T]
               (var read-state nil)
               (let [wrappee {:init #16 :draw #(set read-state $1)}
                     wrapper (breaker.init wrappee)]
                 (breaker.draw wrapper)
                 (T:assert (= read-state 16) "The state gets passed to the wrapped layer"))))
          (T "when calling update with extra arguments"
             (fn [T]
               (var arg nil)
               (let [wrappee {:init #8 :update #(set arg $2)}
                     wrapper (breaker.init wrappee)]
                 (breaker.update wrapper 23)
                 (T:assert (= arg 23) "should pass through extra arguments"))))
          (T "when calling a callback the nested layer doesn't define"
             (fn [T]
               (var draws 0)
               (let [wrapper (breaker.init {:draw #(set draws (+ 1 draws))})]
                 (breaker.update wrapper)
                 (breaker.draw wrapper)
                 (T:assert (= draws 1) "should not attempt to call it on that layer and continue running"))))))
     (T "when the wrapped layer errors"
        (fn [T]
          (T "and is called multiple times"
             (fn [T]
               (var call-count 0)
               (let [wrappee {:init #nil :draw (fn []
                                                 (set call-count (+ 1 call-count))
                                                 (error "Testing failure"))}
                     wrapper (breaker.init wrappee)]
                 (breaker.draw wrapper)
                 (breaker.draw wrapper)
                 (breaker.draw wrapper)
                 (T:assert (= call-count 1) "should stop passing through callbacks"))))
          (T "and has an on-fault callback"
             (fn [T]
               (var call-count 0)
               (let [wrappee {:init #nil :draw #(error "Testing failure")}
                     wrapper (breaker.init wrappee #(set call-count (+ 1 call-count)))]
                 (breaker.draw wrapper)
                 (T:assert (= call-count 1) "should call it on the first failure")
                 (breaker.draw wrapper)
                 (T:assert (= call-count 1) "should call it on only the first failure"))))))))