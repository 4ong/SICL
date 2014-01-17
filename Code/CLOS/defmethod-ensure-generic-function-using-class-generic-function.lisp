(cl:in-package #:sicl-clos)

(defmethod ensure-generic-function-using-class
    ((generic-function generic-function)
     function-name
     &rest
       all-keyword-arguments
     &key
       (generic-function-class *standard-generic-function*)
       (method-class nil method-class-p)
     &allow-other-keys)
  (cond ((symbolp generic-function-class)
	 (let ((class (find-class generic-function-class nil)))
	   (when (null class)
	     (error "no such generic-function-class ~s"
		    generic-function-class))
	   (setf generic-function-class class)))
	((classp generic-function-class)
	 nil)
	(t
	 (error "generic function class must be a class or a name")))
  (unless (eq generic-function-class (class-of generic-function))
    (error "classes don't agree"))
  (when method-class-p
    (cond ((symbolp method-class)
	   (let ((class (find-class method-class nil)))
	     (when (null class)
	       (error "no such method class ~s" method-class))
	     (setf method-class class)))
	  ((classp method-class)
	   nil)
	  (t
	   (error "method class must be a class or a name"))))
  (let ((remaining-keys (copy-list all-keyword-arguments)))
    (loop while (remf remaining-keys :generic-function-class))
    (if method-class-p
	(apply #'reinitialize-instance generic-function
	       :method-class method-class
	       remaining-keys)
	(apply #'reinitialize-instance generic-function
	       remaining-keys)))
  generic-function)
