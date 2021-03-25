(local {: new-block} (require :lib/block))
(local {: new-hand} (require :lib/hand))
(local {: new-log} (require :lib/logging))

;; TODO(cromo): Make this less global. It would be better for parts of this tree
;; to be injected into the code that needs it and needs to modify it instead of
;; everything needing to know the global structure of the store.
(global store
        {:input
         {:hand/left (new-hand)
          :hand/right (new-hand)
          :text-index 1
          :mode :physical
          :text-focus nil}
         :logs (new-log)
         :blocks [(new-block 0 1 -0.4)]
         :elapsed {:frames 0 :seconds 0}
         :config
         {:headset {:refresh-rate-hz (lovr.headset.getDisplayFrequency)}
          :repeat {:delay 0.7 :hz 0.05}
          :character-list " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"}})