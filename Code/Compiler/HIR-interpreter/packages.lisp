(cl:in-package #:common-lisp-user)

(defpackage #:sicl-hir-interpreter
  (:use #:common-lisp)
  (:export #:cst-eval
           #:top-level-hir-to-host-function))
