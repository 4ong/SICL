(cl:in-package #:sicl-extrinsic-environment)

;;; Introduce immediates where appropriate.  The definition of the
;;; generic function says that we return an integer if we want to
;;; introduce an immediate value, and NIL if we do not want to
;;; introduce an immediate value.
(defmethod cleavir-generate-ast:convert-constant-to-immediate
    (constant (environment environment) system)
  (declare (ignore system))
  (cond ((and (typep constant 'integer)
	      (<= #.(- (expt 2 30)) constant #.(1- (expt 2 30))))
	 (* 2 constant))
	((typep constant 'character)
	 ;; FIXME: Currently, we depend on the host having the same
	 ;; character encoding as the target.
	 (+ #b11 (ash (char-code constant) 3)))
	(t
	 nil)))

;;; When we are asked to compile the name of a global function, by
;;; default Cleavir generates an FDEFINITION-AST taking the function
;;; name as an input.  For SICL, we do not want that.  Instead we want
;;; it to generate an access to the CAR of the global function cell
;;; that contains the function.  And we want the function cell to be
;;; accessed at load time.
(defmethod cleavir-generate-ast:convert-global-function
    ((info cleavir-env:global-function-info) (env environment) system)
  (declare (ignore system))
  (cleavir-ast:make-car-ast
   (cleavir-ast:make-load-time-value-ast
    `(sicl-genv:function-cell
      ',(cleavir-env:name info)
      (sicl-genv:global-environment))
    ;; The cell is not read-only.
    nil)))

;;; When we are asked to compile the name of a special variable, by
;;; default Cleavir generates a SYMBOL-VALUE-AST taking the variable
;;; name as an input.  For SICL, we do not want that.  Instead we want
;;; it to generate a call to the function
;;; SICL-EXTRINSIC-ENVIRONMENT:SYMBOL-VALUE, passing it the symbol
;;; naming the variable and the GLOBAL ENVIRONMENT.
;;;
;;; The global environment is used by the function
;;; SICL-EXTRINSIC-ENVIRONMENT:SYMBOL-VALUE to retrieve the value
;;; representing UNBOUND in that environment, and to retrieve the
;;; global value cell in case the variable is not bound in the dynamic
;;; run-time environment.
(defmethod cleavir-generate-ast:convert-special-variable
    ((info cleavir-env:special-variable-info) (env environment) system)
  (declare (ignore system))
  (cleavir-ast:make-call-ast
   (cleavir-ast:make-car-ast
    (cleavir-ast:make-load-time-value-ast
     '(sicl-genv:function-cell
       'sicl-extrinsic-environment:symbol-value
       (sicl-genv:global-environment))))
   (list (cleavir-ast:make-load-time-value-ast
	  `',(cleavir-env:name info)
	  t)
	 (cleavir-ast:make-load-time-value-ast
	  'sicl-genv:*global-environment*
	  t))))

;;; When we are asked to compile an assignment to a special variable,
;;; by default Cleavir generates a SET-SYMBOL-VALUE-AST taking the
;;; variable name and the value as an input.  For SICL, we do not want
;;; that.  Instead we want it to generate a call to (SETF
;;; SICL-EXTRINSIC-ENVIRONMENT:SYMBOL-VALUE), passing it the new
;;; value, the symbol naming the variable, and the environment.
(defmethod cleavir-generate-ast:convert-setq-special-variable
    ((info cleavir-env:special-variable-info) form-ast (env environment) system)
  (declare (ignore system))
  (cleavir-ast:make-call-ast
   (cleavir-ast:make-car-ast
    (cleavir-ast:make-load-time-value-ast
     '(sicl-genv:function-cell
       '(setf sicl-extrinsic-environment:symbol-value)
       sicl-genv:*global-environment*)))
   (list form-ast
	 (cleavir-ast:make-load-time-value-ast
	  `',(cleavir-env:name info)
	  t)
	 (cleavir-ast:make-load-time-value-ast
	  'sicl-genv:*global-environment*
	  nil))))

;;; The default method on CLEAVIR-GENERATE-AST:CONVERT-SPECIAL-BINDING
;;; generates a call to CLEAVIR-PRIMOP:CALL-WITH-VARIABLE-BOUND, but
;;; that function does not have a default definition.  We define that
;;; function under a different name here, and then we import it into
;;; the environment with the name that is used by
;;; CONVERT-SPECIAL-BINDING
;;;
;;; Notice that this function must be a host function.  It accesses
;;; the host variable *DYNAMIC-ENVIRONMENT* which the caller SETS to
;;; its dynamic run-time environment immediately before the call.  In
;;; order to follow the same protocol, we must also SET this variable
;;; before calling THUNK.
(defun call-with-variable-bound (variable-name value thunk)
  (setf *dynamic-environment*
	(cons (make-instance 'variable-binding
		:symbol variable-name
		:value value)
	      *dynamic-environment*))
  (funcall thunk))

;;; For this environment, whenever Cleavir asks for information about
;;; a function name and that function name is a symbol in the
;;; CLEAVIR-PRIMOP package, we want to return an object of type
;;; CLEAVIR-ENV:SPECIAL-OPERATOR-INFO so that the form can be treated
;;; as a special form by GENERATE-AST.
(defmethod cleavir-env:function-info :around ((env environment) function-name)
  (if (and (symbolp function-name)
	   (eq (symbol-package function-name)
	       (find-package '#:cleavir-primop)))
      (make-instance 'cleavir-env:special-operator-info
	:name function-name)
      (call-next-method)))
