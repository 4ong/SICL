(cl:in-package #:common-lisp-user)

(defpackage #:sicl-extrinsic-environment
  (:use #:common-lisp)
  (:shadow #:load
	   #:catch
	   #:throw
	   #:unwind-protect
	   #:symbol
	   #:symbol-value)
  (:export #:*environment*))
