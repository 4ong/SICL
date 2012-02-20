(in-package #:common-lisp-user)

(asdf:defsystem #:sicl-additional-conditions
  :depends-on (#:sicl-internationalization #:sicl-additional-types)
  :components
  ((:file "packages")
   (:file "conditions" :depends-on ("packages"))
   (:file "condition-reporters-en" :depends-on ("packages" "conditions"))))
