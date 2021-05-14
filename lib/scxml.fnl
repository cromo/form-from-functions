(local module {})

(fn xml-tag [tag allowed-attributes]
  (fn [attributes ...]
    (let [attribute-strings (icollect [_ attribute (ipairs allowed-attributes)]
                                      (when (. attributes attribute)
                                        (.. attribute "=\"" (. attributes attribute) "\"")))
          children [...]]
      (.. "<" tag " " (table.concat attribute-strings " ") ">\n"
          (table.concat children "\n")
          "\n</" tag ">"))))

;; The attributes are as defined in the SCXML spec: https://www.w3.org/TR/scxml/
(local raw-statechart (xml-tag :scxml [:xmlns :version :initial :name :datamodel :binding]))

(fn module.statechart [attributes ...]
  (set attributes.xmlns "http://www.w3.org/2005/07/scxml")
  (set attributes.version "1.0")
  (raw-statechart attributes ...))
(set module.state (xml-tag :state [:id :initial]))
(set module.parallel (xml-tag :parallel [:id]))
(set module.transition (xml-tag :transition [:event :cond :target :type]))
(set module.initial (xml-tag :initial []))
(set module.final (xml-tag :final [:id]))
(set module.on-entry (xml-tag :onentry []))
(set module.on-exit (xml-tag :onexit []))
(set module.history (xml-tag :history [:id :type]))

module