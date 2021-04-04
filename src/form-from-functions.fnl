(local fennel (require :third-party/fennel))

(local logging-breaker (require :lib/logging-breaker))
(local text-input (require :lib/disk-text-input))
(local block (require :lib/block))
(local blocks (require :lib/blocks))
(local {: generate-code} (require :lib/code-gen))
(local elapsed-time (require :lib/elapsed-time))
(local hand (require :lib/hand))
(local log (require :lib/logging))
(local persistence (require :src/persistence))

(local store
       {:input
        {:hand/left (hand.init :hand/left)
         :hand/right (hand.init :hand/right)
         :mode :physical
         :text-focus nil}
        :blocks (blocks.init)
        :text-input (text-input.init)
        :elapsed (elapsed-time.init)})

(local form-from-functions {})

(local text-input (logging-breaker.init text-input))
(local {:wasPressed was-pressed
        :wasReleased was-released} lovr.headset)

(fn form-from-functions.load []
  (log.info :config (.. "Save directory: " (lovr.filesystem.getSaveDirectory)))
  (when (persistence.blocks-file-exists?)
    (set store.blocks (persistence.load-blocks-file))))

(fn grab-nearby-block-if-able [hand blocks]
  (let [nearby-blocks (icollect [_ block (ipairs store.blocks)]
                                (when (< (: (- hand.position block.position) :length) 0.1) block))
        nearest-block (. nearby-blocks 1)]
    (set hand.contents nearest-block)))

(fn adapt-physical-oculus-touch-input []
  {:evaluate (was-pressed :hand/right :a)
   :save (was-pressed :hand/right :b)
   :create-block (was-pressed :hand/left :x)
   :link (or (was-pressed :hand/left :trigger)
             (was-pressed :hand/right :trigger))
   :grab {:left (was-pressed :hand/left :grip)
          :right (was-pressed :hand/right :grip)}
   :drop {:left (was-released :hand/left :grip)
          :right (was-released :hand/right :grip)}
   :write-text (was-pressed :hand/left :y)})

(fn adapt-textual-oculus-touch-input []
  {:stop (was-pressed :hand/left :y)})

(fn physical-update [dt]
  (match (adapt-physical-oculus-touch-input)
    {:evaluate true}
    (xpcall
     (fn [] (fennel.eval (generate-code store.blocks)))
     (fn [error]
       (log.error :codegen error)))
    {:save true}
    (persistence.save-blocks-file store.blocks)

    {:create-block true}
    (blocks.add store.blocks (block.init (store.input.hand/left.position:unpack)))
    ({:link true} ? store.input.hand/left.contents store.input.hand/right.contents)
    (block.link store.input.hand/left.contents store.input.hand/right.contents)

    {:grab {:left true}}
    (grab-nearby-block-if-able store.input.hand/left store.blocks)
    {:grab {:right true}}
    (grab-nearby-block-if-able store.input.hand/right store.blocks)
    {:drop {:left true}}
    (set store.input.hand/left.contents nil)
    {:drop {:right true}}
    (set store.input.hand/right.contents nil)

    ({:write-text true} ? store.input.hand/left.contents)
    (do (set store.input.text-focus store.input.hand/left.contents)
        (set store.input.hand/left.contents nil)))
  (if store.input.text-focus :textual :physical))

(fn textual-update [dt]
  (logging-breaker.update text-input dt store.input.text-focus)
  (match (adapt-textual-oculus-touch-input)
    {:stop true} (set store.input.text-focus nil))
  (if store.input.text-focus :textual :physical))

(fn form-from-functions.update [dt]
  (elapsed-time.update store.elapsed dt)
  (hand.update store.input.hand/left)
  (hand.update store.input.hand/right)
  (set store.input.mode
       (match store.input.mode
         :physical (physical-update dt)
         :textual (textual-update dt))))

(fn form-from-functions.draw []
  (elapsed-time.draw store.elapsed)
  (log.draw)
  (lovr.graphics.print
   (.. (hand.format store.input.hand/left) "\n    "
       (hand.format store.input.hand/right))
   -0.03 1.3 -2 0.1)
  (each [_ hand-name (pairs [:hand/left :hand/right])]
        (hand.draw (. store.input hand-name)))
  (blocks.draw store.blocks)
  (logging-breaker.draw text-input))

form-from-functions