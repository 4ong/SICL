(cl:in-package #:sicl-clos)

(defmacro defmethod (&rest arguments)
  (multiple-value-bind (name qualifiers lambda-list specializers body)
      (parse-defmethod arguments)
    (let ((generic-function-var (gensym)))
      `(let ((,generic-function-var (ensure-generic-function ',name)))
	 (ensure-method
	  ,generic-function-var
	  :lambda-list ',lambda-list
	  :qualifiers ',qualifiers
	  :specializers ,(canonicalize-specializers specializers)
	  :body ',body
	  :function ,(make-method-lambda
		      generic-function-var
		      nil
		      `(lambda ,lambda-list ,@body)
		      nil))))))

