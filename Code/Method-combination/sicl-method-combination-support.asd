(cl:in-package #:asdf-user)

(defsystem #:sicl-method-combination-support
  :depends-on (#:cleavir-code-utilities
               #:sicl-clos-package
               #:sicl-global-environment
               #:concrete-syntax-tree)
  :serial t
  :components
  ((:file "packages")
   (:file "method-combination-template-defclass")
   (:file "lambda-list-variables")
   (:file "method-group-specifier")
   (:file "method-discriminator")
   (:file "long-form-expansion")
   (:file "short-form-expansion")
   (:file "define-method-combination-support")
   (:file "find-method-combination")))
