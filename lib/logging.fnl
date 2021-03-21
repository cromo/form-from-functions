(local logging {})

(fn logging.log [level tag message]
  (set store.logs (.. store.logs "\n" level " " tag " " message)))

logging