(cl:in-package #:sicl-global-environment)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Function BOUNDP.
;;;
;;; According to the HyperSpec, this function should return any true
;;; value if the name is bound in the global environment and false
;;; otherwise.  We return T when the symbol is bound.  
;;;
;;; The HyperSpec does not say whether the name of a constant variable
;;; is considered to be bound.  We think it is reasonable to consider
;;; it bound in this case.  They HyperSpec also does not say whether
;;; the name of a global symbol macro is considered to be bound.
;;; Again, we think it is reasonable to consider this to be the case,
;;; if for nothing else, then for symmetry with fboundp.
;;;
;;; The symbol is bound as a special variable if it is both the case
;;; that a special variable entry exists for it AND the storage cell
;;; of that entry does not contain +unbound+.

(defun boundp (symbol)
  (declare (cl:type symbol symbol))
  (not (null (or (find symbol (constant-variables *global-environment*)
		       :key #'name :test #'eq)
		 (find symbol (symbol-macros *global-environment*)
		       :key #'name :test #'eq)
		 (find-if (lambda (entry)
			    (and (eq (name entry) symbol)
				 (not (eq (car (storage (location entry)))
					  +unbound+))))
			  (special-variables *global-environment*))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Function MAKUNBOUND.
;;;
;;; Since we consider a name bound if it names a constant variable, or
;;; if it names a global symbol macro, we must decide what to do in
;;; those cases.  It would be embarassing for someone to call
;;; MAKUNBOUND successfully and then have BOUNDP return true.  What we
;;; do is to remove the symbol macro if any, and signal an error if an
;;; attempt is made to make a constant variable unbound.

(defun makunbound (symbol)
  (declare (cl:type symbol symbol))
  ;; Check whether the symbol has a definition as a constant variable.
  (let ((constant-variable-entry
	  (find symbol (constant-variables *global-environment*)
		:key #'name :test #'eq)))
    (if (not (null constant-variable-entry))
	(error "Attemp to make a constant variable unbound")
	;; Check whether the symbol has a definition as a global
	;; symbol macro.
	(let ((macro-entry
		(find symbol (symbol-macros *global-environment*)
		      :key #'name :test #'eq)))
	  (if (not (null macro-entry))
	      (progn
		;; Remove the symbol macro entry.
		(setf (symbol-macros *global-environment*)
		      (delete macro-entry (symbol-macros *global-environment*)
			      :test #'eq))
		;; The symbol macro might have a type proclamation
		;; associated with it.  Remove that too.
		(setf (proclamations *global-environment*)
		      (delete-if (lambda (entry)
				   (and (typep entry 'auxiliary-entry)
					(eq (base-entry entry) macro-entry)))
				 (proclamations *global-environment*))))
	      ;; Check whether the symbol has a definition as a
	      ;; special variable.
	      (let ((variable-entry
		      (find symbol (special-variables *global-environment*)
			    :key #'name :test #'eq)))
		(unless (null variable-entry)
		  ;; Set the storage cell to +unbound+
		  (setf (car (storage (location variable-entry))) +unbound+)
		  ;; The variable might have a various proclamation
		  ;; associated with it.  Remove those too.
		  (setf (proclamations *global-environment*)
			(delete-if (lambda (entry)
				     (and (typep entry 'auxiliary-entry)
					  (eq (base-entry entry) macro-entry)))
				   (proclamations *global-environment*)))))))))
  ;; Return the symbol as required by the HyperSpec
  symbol)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Function SYMBOL-VALUE.
;;;
;;; The HyperSpec specifically allows for SYMBOL-VALUE to be used on
;;; constant variables.  

(defun symbol-value (symbol)
  (declare (cl:type symbol symbol))
  ;; Handle keyword symbols specially here.
  (if (keywordp symbol)
      symbol
      ;; Next check whether the symbol has a defintion as a constant
      ;; variable. 
      (let ((constant-variable-entry
	      (find symbol (constant-variables *global-environment*)
		    :key #'name :test #'eq)))
	(if (not (null constant-variable-entry))
	    (definition constant-variable-entry)
	    ;; Check whether the symbol has a definition as a special
	    ;; variable, and check whether it is bound. 
	    (let ((special-variable-entry
		    (find symbol (special-variables *global-environment*)
			  :key #'name :test #'eq)))
	      (if (not (null special-variable-entry))
		  (let ((val (car (storage (location special-variable-entry)))))
		    (if (eq val +unbound+)
			(error 'unbound-variable :name symbol)
			val))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Auxiliary function ENSURE-DEFINED-VARIABLE.
;;;
;;; This function checks whether there is an entry for a name as a
;;; special variable in the global environment, and if not creates
;;; such an entry.  If the entry exists, but is not marked as DEFINED,
;;; then this function marks it as such.
;;;
;;; If the name is already that of a constant variable, then an error
;;; is signaled.
;;;
;;; If there is an entry for the name as a global macro then an error
;;; is signaled.

(defun ensure-defined-variable (name)
  (when (constantp name)
    (error "Attempt to redefine a constant variable."))
  (unless (null (find name (symbol-macros *global-environment*)
		      :key #'name :test #'eq))
    (error "Attempt to redefine a global symbol macro as a variable."))
  (let ((entry (find name (special-variables *global-environment*)
		     :key #'name :test #'eq)))
    (if (null entry)
	(push (make-special-variable-entry name t)
	      (special-variables *global-environment*))
	(setf (defined-p entry) t)))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Function (SETF SYMBOL-VALUE).
;;;
;;; Signal an error if an attempt is made to call this function with
;;; the name of a constant variable.
;;;
;;; The Hyperspec does not indicate what should be done if this
;;; function is called and the name already has a definition as a
;;; global symbol macro.  However, it does say that an error is
;;; signaled in the opposite situation, i.e., if an attempt is made to
;;; define a symbol macro with a name of an existing special variable.
;;; For that reason, we think it is reasonable to signal an error in
;;; this case too.

(defun (setf symbol-value) (new-value symbol)
  (declare (symbol symbol))
  ;; Handle keyword symbols specially here.
  (when (keywordp symbol)
    (error "attempt to change the value of a keyword."))
  ;; Next check whether the symbol has a defintion as a constant
  ;; variable. 
  (when (constantp symbol)
    (error "attempt to change the value of a constant variable"))
  ;; Calling this function implicitly DEFINES the variable.
  (ensure-defined-variable symbol)
  ;; Find out everything about the variable. 
  (let ((info (variable-info symbol nil)))
    (unless (typep new-value (type info))
      (error 'type-error
	     :datum new-value
	     :expected-type (type info)))
    (setf (car (storage (location info)))
	  new-value))
  ;; Return the new value as the HyperSpec requires.
  new-value)

