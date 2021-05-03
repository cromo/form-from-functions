(local binder (require :lib/adapters/binder))

(T "A binder layer"
   (fn [T]
     (T "when used"
        (fn [T]
          (T "should pass through state with : calls"
             (fn [T]
               (var test nil)
               (let [wrappee {:init #{:state 1} :update #(set test $1.state)}
                     wrapper (binder.init wrappee)]
                 (wrapper:update)
                 (T:assert (= test 1) "State was not passed through"))))))))
