(local logging {})

(fn logging.log [level tag message]
  (set store.logs (.. store.logs "\n" level " " tag " " message)))

(fn logging.draw-logs [logs]
  (lovr.graphics.print logs 0 1.7 -3 0.1 0 0 1 0 0 :center :bottom))

logging