(local {:init text-input} (require :lib/disk-text-input))
(local {:init elapsed-time} (require :lib/elapsed-time))
(local {: new-block} (require :lib/block))
(local {:init new-hand} (require :lib/hand))
(local {: new-log} (require :lib/logging))

;; TODO(cromo): Make this less global. It would be better for parts of this tree
;; to be injected into the code that needs it and needs to modify it instead of
;; everything needing to know the global structure of the store.
(global store
        {:input
         {:hand/left (new-hand :hand/left)
          :hand/right (new-hand :hand/right)
          :mode :physical
          :text-focus nil}
         :logs (new-log)
         :blocks [(new-block 0 1 -0.4)]
         :text-input (text-input)
         :elapsed (elapsed-time)
         :config
         {:headset {:refresh-rate-hz (lovr.headset.getDisplayFrequency)}
          :repeat {:delay 0.7 :hz 0.05}}})