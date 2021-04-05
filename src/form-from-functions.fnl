(local {:headset {:wasPressed was-pressed
                  :wasReleased was-released}} lovr)
(local fennel (require :third-party/fennel))

(local breaker (require :lib/logging-breaker))
(local text-input (require :lib/disk-text-input))
(local block (require :lib/block))
(local blocks (require :lib/blocks))
(local {: generate-code} (require :lib/code-gen))
(local elapsed-time (require :lib/elapsed-time))
(local hand (require :lib/hand))
(local log (require :lib/logging))
(local persistence (require :src/persistence))

(local form-from-functions {})
(local hands
       {:left (hand.init :hand/left)
        :right (hand.init :hand/right)})
(var input-mode :physical)
(var user-blocks (blocks.init))
(var text-focus nil)
(local elapsed (elapsed-time.init))
(local text-input (breaker.init text-input))

(var user-layer (breaker.init {}))

(fn form-from-functions.load []
  (log.info :config (.. "Save directory: " (lovr.filesystem.getSaveDirectory)))
  (when (persistence.blocks-file-exists?)
    (set user-blocks (persistence.load-blocks-file))))

(fn grab-nearby-block-if-able [hand blocks]
  (let [nearby-blocks (icollect [_ block (ipairs user-blocks)]
                                (when (< (: (- hand.position block.position) :length) 0.1) block))
        nearest-block (. nearby-blocks 1)]
    (set hand.contents nearest-block)))

(fn adapt-physical-oculus-touch-input []
  {:evaluate (was-pressed :hand/right :a)
   :save (was-pressed :hand/right :b)
   :reify-block (was-pressed :hand/left :x)
   :link (or (was-pressed :hand/left :trigger)
             (was-pressed :hand/right :trigger))
   :grab {:left (was-pressed :hand/left :grip)
          :right (was-pressed :hand/right :grip)}
   :drop {:left (was-released :hand/left :grip)
          :right (was-released :hand/right :grip)}
   :write-text (was-pressed :hand/left :y)})

(fn adapt-textual-oculus-touch-input []
  {:stop (was-pressed :hand/left :y)})

(local available-input-adapters
       {:oculus {:physical adapt-physical-oculus-touch-input
                 :textual adapt-textual-oculus-touch-input}})

(local input-adapter available-input-adapters.oculus)

(fn physical-update [dt]
  (match (input-adapter.physical)
    {:evaluate true}
    (xpcall
     (fn [] (set user-layer (breaker.init (fennel.eval (generate-code user-blocks)))))
     (fn [error]
       (log.error :codegen error)))
    {:save true}
    (persistence.save-blocks-file user-blocks)

    ({:reify-block true} ? hands.left.contents)
    (let [block-to-remove hands.left.contents]
      (set hands.left.contents nil)
      (blocks.remove user-blocks block-to-remove))
    {:reify-block true}
    (blocks.add user-blocks (block.init (hands.left.position:unpack)))
    ({:link true} ? hands.left.contents hands.right.contents)
    (block.link hands.left.contents hands.right.contents)

    {:grab {:left true}}
    (grab-nearby-block-if-able hands.left user-blocks)
    {:grab {:right true}}
    (grab-nearby-block-if-able hands.right user-blocks)
    {:drop {:left true}}
    (set hands.left.contents nil)
    {:drop {:right true}}
    (set hands.right.contents nil)

    ({:write-text true} ? hands.left.contents)
    (do (set text-focus hands.left.contents)
        (set hands.left.contents nil)))
  (if text-focus :textual :physical))

(fn textual-update [dt]
  (breaker.update text-input dt text-focus)
  (match (input-adapter.textual)
    {:stop true} (set text-focus nil))
  (if text-focus :textual :physical))

(fn form-from-functions.update [dt]
  (elapsed-time.update elapsed dt)
  (hand.update hands.left)
  (hand.update hands.right)
  (set input-mode
       (match input-mode
         :physical (physical-update dt)
         :textual (textual-update dt)))
  (breaker.update user-layer))

(fn form-from-functions.draw []
  (elapsed-time.draw elapsed)
  (log.draw)
  (lovr.graphics.print
   (.. (hand.format hands.left) "\n    "
       (hand.format hands.right))
   -0.03 1.3 -2 0.1)
  (each [_ hand-name (pairs [:left :right])]
        (hand.draw (. hands hand-name)))
  (blocks.draw user-blocks)
  (breaker.draw text-input)
  (breaker.draw user-layer))

form-from-functions