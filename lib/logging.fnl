(local logging {})

(fn logging.new-log []
  {})

(fn logging.log [level tag message]
  (table.insert store.logs {: level : tag : message})
  ;; There's definitely room for optimization here (e.g. circular buffers), but
  ;; working first, fast later.
  (when (< 100 (length store.logs))
    (table.remove store.logs 1)))

(fn format-log [{: level : tag : message}]
  (.. level " " tag " " message))

(fn logging.draw-logs [logs]
  (var offset 0)
  (local font (lovr.graphics.getFont))
  (for [i (length logs) 1 -1]
    (let [log-entry (. logs i)
          log (format-log log-entry)
          (_ lines) (font:getWidth log)]
      (lovr.graphics.print
       log
       0 (+ 1.7 offset) -3
       0.1
       0
       0 1 0 0
       :center :bottom)
      (set offset (+ offset (* 0.1 lines))))))

logging