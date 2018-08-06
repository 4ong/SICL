(cl:in-package #:sicl-extrinsic-environment)

;;; This is a simple version of the Common Lisp LOAD function.  It
;;; differs from the host version by the fact that it uses Eclector to
;;; read the code.  We need to do it that way because we need for the
;;; occurrences of the backquote reader macro character to generate
;;; macro calls to the Eclector version of the corresponding macros.

(defun host-load (relative-filename)
  (let ((*package* *package*)
        (filename (asdf:system-relative-pathname :sicl-extrinsic-environment
                                                 relative-filename)))
    (with-open-file (stream filename :direction :input)
      (loop with eof-marker = (list nil)
            for form = (eclector.reader:read stream nil eof-marker)
            until (eq form eof-marker)
            do (eval form)))))
