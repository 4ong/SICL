(cl:in-package #:sicl-global-environment)

(defmethod cleavir-env:variable-info ((env environment) symbol)
  (multiple-value-bind (value present-p)
      (constant-variable symbol env)
    (if present-p
	;; The symbol is bound to a constant variable.  We need to
	;; return a CONSTANT-VARIABLE-INFO.
	(make-instance 'cleavir-env:constant-variable-info
	  :value value
	  :name symbol)
	;; The symbol is NOT bound to a constant variable.
	;; Perhaps it is bound to a symbol macro?
	(multiple-value-bind (expander expansion)
	    (symbol-macro symbol env)
	  (if (not (null expander))
	      ;; We have a symbol macro.  We need to return a
	      ;; SYMBOL-MACRO-INFO.
	      (make-instance 'cleavir-env:symbol-macro-info
		:name symbol
		:expansion expansion
		:type (variable-type symbol env))
	      ;; The symbol is not bound to a constant variable,
	      ;; and not bound to a symbol macro.  Perhaps it is bound
	      ;; to a special variable?
	      (multiple-value-bind (value present-p)
		  (special-variable symbol env)
		(declare (ignore value))
		(if present-p
		    ;; We have a special variable.  We need to
		    ;; return a SPECIAL-VARIABLE-INFO.
		    (make-instance 'cleavir-env:special-variable-info
		      :name symbol
		      :global-p t
		      :ignore nil
		      :type (variable-type symbol env))
		    ;; This symbol does not seem to be defined.
		    ;; Return NIL as Cleavir requires.
		    nil)))))))

(defmethod cleavir-env:function-info ((env environment) function-name)
  (cond ((fboundp function-name env)
	 (let ((binding (fdefinition function-name env)))
	   (cond ((functionp binding)
		  (make-instance 'cleavir-env:global-function-info
		    :name function-name
		    :dynamic-extent nil
		    :ignore nil
		    :compiler-macro (compiler-macro-function function-name env)
		    :inline (function-inline function-name env)
		    :type (function-type function-name env)
		    :ast (function-ast function-name env)))
		 ((eq (first binding) 'cl:macro-function)
		  (make-instance 'cleavir-env:global-macro-info
		    :name function-name
		    :expander (second binding)
		    :compiler-macro (compiler-macro-function function-name env)))
		 (t
		  (make-instance 'cleavir-env:special-operator-info
		    :name function-name)))))
	((not (null (function-type function-name env)))
	 ;; This means that the type of the function was proclaimed,
	 ;; typically as a result of a compile-time side effect of
	 ;; DEFUN.  We should be nice then and indicate that the
	 ;; function exists.
	 (make-instance 'cleavir-env:global-function-info
	   :name function-name
	   :dynamic-extent nil
	   :ignore nil
	   :compiler-macro (compiler-macro-function function-name env)
	   :inline (function-inline function-name env)
	   :type (function-type function-name env)
	   :ast (function-ast function-name env)))
	(t
	 nil)))
