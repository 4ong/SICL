(cl:in-package #:sicl-boot)

(defun define-find-class (boot)
  (setf (sicl-genv:fdefinition 'find-class (r2 boot))
	(lambda (name-or-class)
	  (if (symbolp name-or-class)
	      (sicl-genv:find-class name-or-class (r1 boot))
	      name-or-class))))
