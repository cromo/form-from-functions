(local logging {})

(fn logging.new-log []
  [])

;; TODO(cromo): Have a mechanism to use an external log state instead of closing
;; over one in this scope.
(local logs (logging.new-log))

(fn logging.log [level tag message]
  (print (.. level " " tag " " message))
  (table.insert logs {:timestamp (os.time) : level : tag : message})
  ;; There's definitely room for optimization here (e.g. circular buffers), but
  ;; working first, fast later.
  (when (< 100 (length logs))
    (table.remove logs 1)))

(fn logging.error [tag message] (logging.log :error tag message))
(fn logging.warning [tag message] (logging.log :warning tag message))
(fn logging.info [tag message] (logging.log :info tag message))
(fn logging.debug [tag message] (logging.log :debug tag message))
(fn logging.verbose [tag message] (logging.log :verbose tag message))

(fn format-log [{: timestamp : level : tag : message}]
  (.. (os.date :%FT%T%z timestamp) " " level " " tag " " message))

(fn logging.draw []
  (var offset 0)
  (local font (lovr.graphics.getFont))
  (for [i (length logs) 1 -1]
    (let [log-entry (. logs i)
          log (format-log log-entry)
          (_ lines) (font:getWidth log)]
      (lovr.graphics.print
       log
       0 (+ 0 offset) -3
       0.1
       0
       0 1 0 0
       :center :bottom)
      (set offset (+ offset (* 0.1 lines))))))

logging