(local module {})

(fn module.statechart [attributes children]
  (.. "<scxml xmlns=\"http://www.w3.org/2005/07/scxml\" version=\"1.0\">\n"
      (table.concat children "\n")
      "\n</scxml>"))

(fn module.state [{: id} children]
  (.. "<state "
      (if id (.. "id=\"" id "\"") "")
      ">\n"
      (table.concat children "\n")
      "\n</state>\n"))

(fn module.transition [attributes]
  (let [attribute-strings (icollect [_ attribute (ipairs [:event :target])]
                                    (when (. attributes attribute)
                                      (.. attribute "=\"" (. attributes attribute) "\"")))]
    (.. "<transition "
        (table.concat attribute-strings " ")
        "></transition>")))

module