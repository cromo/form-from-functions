(local logging {})

(fn logging.log [level tag message]
  (set store.logs (.. store.logs "\n" level " " tag " " message)))

(fn logging.draw-logs [logs]
  (lovr.graphics.print logs 0 1.5 -3 0.1 0 0 1 0 0 :center :top))

logging