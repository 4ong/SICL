(cl:in-package #:sicl-clos)

;;;; This file contains the support code for the generic functions
;;;; ADD-METHOD and REMOVE-METHOD.
;;;;
;;;; In this file, there are no definitions of generic functions, nor
;;;; of any methods.  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Utilities

;;; Update the specializer profile of a generic function according to
;;; a list of specializers of a method.
(defun update-specializer-profile (generic-function specializers)
  (setf (specializer-profile generic-function)
	(loop for specializer in specializers
	      for p in (specializer-profile generic-function)
	      collect (if (and (classp specializer)
			       (= (unique-number specializer) 0))
			  p
			  t))))

;;; Compute a completely new specializer profile for a generic
;;; function.
(defun compute-and-set-specializer-profile (generic-function)
  ;; Keep the length of the profile, but with all elements NIL.
  (setf (specializer-profile generic-function)
	(make-list (length (specializer-profile generic-function))))
  (loop for method in (generic-function-methods generic-function)
	do (update-specializer-profile generic-function method)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Generic function ADD-METHOD.
;;;
;;; For the specification of this generic function, see
;;; http://metamodular.com/CLOS-MOP/add-method.html
;;;
;;; The specification includes a single method on this generic
;;; function, specialized for STANDARD-GENERIC-FUNCTION and
;;; STANDARD-METHOD.  The default action below is valid for that
;;; method.

(defun add-method-default (generic-function method)
  (unless (null (method-generic-function method))
    (error "method is already associated with a generic-function ~s"
	   method))
  ;; FIXME: check that the lambda list are congruent
  ;;
  ;; See if GENERIC-FUNCTION has a method with the same specializers
  ;; and the same qualifiers as METHOD.  If such a method exists, it
  ;; must be removed before this method is added.
  (let ((method-to-remove
	  (find-if (lambda (existing-method)
		     ;; They must have the same qualifiers
		     ;; and the same specializers.
		     (and (null (set-exclusive-or
				 (method-qualifiers method)
				 (method-qualifiers existing-method)))
			  (equal (method-specializers method)
				 (method-specializers existing-method))))
		   (gf-methods generic-function))))
    (unless (null method-to-remove)
      (remove-method generic-function method-to-remove)))
  ;; Add this method to the set of methods of this generic function.
  (setf (gf-methods generic-function)
	(cons method (gf-methods generic-function)))
  ;; Update the specializer-profile of the generic-function according
  ;; to the specializers of the method.
  (update-specializer-profile generic-function (method-specializers method))
  ;; Associate GENERIC-FUNCTION with METHOD.
  (setf (m-generic-function method) generic-function)
  ;; Call ADD-DIRECT-METHOD for each of the specializers of METHOD.
  (loop for specializer in (method-specializers method)
	do (add-direct-method specializer method))
  ;; Call COMPUTE-DISCRIMINATING-FUNCTION and install its result
  ;; with SET-FUNCALLABLE-INSTANCE-FUNCTION. 
  (let ((df (compute-discriminating-function generic-function)))
    (set-funcallable-instance-function generic-function df))
  ;; Update the dependents of GENERIC-FUNCTION.
  (map-dependents generic-function
		  (lambda (dependent)
		    (update-dependent generic-function
				      dependent
				      'add-method
				      method))))
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Generic function REMOVE-METHOD.
;;;
;;; For the specification of this generic function, see
;;; http://metamodular.com/CLOS-MOP/remove-method.html
;;;
;;; The specification includes a single method on this generic
;;; function, specialized for STANDARD-GENERIC-FUNCTION and
;;; STANDARD-METHOD.  The default action below is valid for that
;;; method.

(defun remove-method-default (generic-function method)
  ;; Remove METHOD from the methods of GENERIC-FUNCTION.
  (setf (gf-methods generic-function)
	(remove method (gf-methods generic-function)))
  ;; Compute a new specializer profile for the generic function.
  (compute-and-set-specializer-profile generic-function)
  ;; Call REMOVE-DIRECT-METHOD for each of the specializers of METHOD.
  (loop for specializer in (method-specializers method)
	do (remove-direct-method specializer method))
  ;; Disassociate GENERIC-FUNCTION from METHOD.
  (setf (m-generic-function method) nil)
  ;; Call COMPUTE-DISCRIMINATING-FUNCTION and install its result
  ;; with SET-FUNCALLABLE-INSTANCE-FUNCTION. 
  (let ((df (compute-discriminating-function generic-function)))
    (set-funcallable-instance-function generic-function df))
  ;; Update the dependents of GENERIC-FUNCTION.
  (map-dependents generic-function
		  (lambda (dependent)
		    (update-dependent generic-function
				      dependent
				      'remove-method
				      method))))
