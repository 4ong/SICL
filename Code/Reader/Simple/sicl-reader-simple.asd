(cl:in-package #:common-lisp-user)

(asdf:defsystem :sicl-reader-simple
  :depends-on (:sicl-code-utilities)
  :components
  ((:file "packages")
   (:file "more-variables"
    :depends-on ("packages"))
   (:file "additional-conditions"
    :depends-on ("packages"))
   (:file "readtable"
    :depends-on ("packages" "more-variables"))
   (:file "utilities"
    :depends-on ("packages" "more-variables" "readtable"))
   (:file "tokens"
    :depends-on ("packages" "readtable" "more-variables"))
   (:file "reader"
    :depends-on ("packages" "readtable" "tokens" "more-variables" "utilities"))
   (:file "macro-functions"
    :depends-on ("packages" "more-variables" "utilities"))
   (:file "init"
    :depends-on ("readtable" "macro-functions"))))

