; A small wrapper around knife's test module to run fennel files instead of lua
; files.

(local fennel (require :third-party/fennel))
(local T (require :third-party/knife-test))

(set _G.T T)
(each [_ test-file (ipairs arg)]
      (fennel.dofile test-file))