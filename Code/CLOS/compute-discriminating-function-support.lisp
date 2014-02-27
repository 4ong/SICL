(cl:in-package #:sicl-clos)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Call profile.
;;;
;;; A CALL PROFILE of a particular call to a generic function is a
;;; list of classes of the required arguments passed to the generic
;;; function in that call.  The call profile has the same order as the
;;; required parameters of the generic function, independently of the
;;; argument precedence order of the function.  The call profile is
;;; what is passed to COMPUTE-APPLICABLE-METHODS-USING-CLASSES in
;;; order to determine whether a list of applicable methods can be
;;; computed, using only the classes of the required arguments.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Specializer profile.
;;;
;;; The SPECIALIZER PROFILE of a generic function is a proper list,
;;; the length of which is the number of required parameters of the
;;; generic function.  The specializer profile represents a condensed
;;; version of the information concerning the specializers of the
;;; methods of the generic function.  Each element of the specializer
;;; profile is either T or NIL.  The element is T when there exists a
;;; method on the generic function with a specializer other than the
;;; class T in the corresponding parameter position.  The element is
;;; NIL when every method on the generic function has the class T as a
;;; specializer in the corresponding parameter position.  Arguments to
;;; the generic function corresponding to a specializer profile
;;; element of NIL make no difference in determining the applicable
;;; methods for a particular call.
;;;
;;; The specializer profile must be updated when methods are added or
;;; removed from the generic function.  When a method is added, each
;;; specializer of that method which is not the class named T causes
;;; the corresponding element of the specializer profile to be set to
;;; T.  When a method is removed, the specializer profile is initially
;;; set to a list of a NIL elements.  Then the list of methods of the
;;; generic function is traversed and the specializer profile is
;;; updated as if each method were just added to the generic function.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Class number cache.
;;;
;;; A CLASS NUMBER CACHE of a particular call to a generic function is
;;; a list of unique numbers of classes of specialized required
;;; arguments passed in that call.  These classes (together with the
;;; classes of the other required arguments) were passed to
;;; COMPUTE-APPLICABLE-METHODS-USING-CLASSES, at some point, and that
;;; function was able to compute an applicable method using only those
;;; classed, which is why we have a corresponding class number cache
;;; available.  The length of a class number cache is that of the
;;; number of required arguments that are specialized, or
;;; equivalently, the number of entries equal to T in the specializer
;;; profile of the generic function.  The list is ordered from left to
;;; right, i.e., the first element of the list corresponds to the
;;; leftmost specialized required argument, etc.  In other words, the
;;; order of the elements in the class number cache is independent of
;;; the argument precedence order of the generic function.
;;;
;;; For a particular call to a generic function, if the unique numbers
;;; of the classes of the specialized required arguments correspond to
;;; the unique numbers of the classes in a class number cache, then we
;;; have already at some point determined a list of applicable methods
;;; for that call, so we do not have to compute it again. 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Applicable method cache.
;;;
;;; An APPLICABLE METHOD CACHE of a particular call to a generic
;;; function is list of applicable methods, as returned by the generic
;;; function COMPUTE-APPLICABLE-METHODS-USING-CLASSES when called with
;;; the classes in the call profile.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Effective method cache.
;;;
;;; An EFFECTIVE METHOD CACHE for a particular applicable method cache
;;; is the result of calling the generic function
;;; COMPUTE-EFFECTIVE-METHOD, passing it the list of methods of that
;;; applicable method cache.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Call cache.
;;;
;;; A CALL CACHE represents information about a particular call to a
;;; generic function.  It is represented as a proper list with at
;;; least 2 CONS cells in it, and it conceptually contains 3 items:
;;;
;;;   1. A class number cache.  This item is located in the CAR of the
;;;      list representing the call cache.
;;;
;;;   2. An applicable method cache.  This item is located in the CDDR
;;;      of the list representing the call cache.
;;;
;;;   3. An effective method cache.  This item is located in the CADR
;;;      of the list representing the call history entry.

(defun make-call-cache
    (class-number-cache applicable-method-cache effective-method-cache)
  (list* class-number-cache effective-method-cache applicable-method-cache))

(defun class-number-cache (call-cache)
  (car call-cache))

(defun applicable-method-cache (call-cache)
  (cddr call-cache))

(defun effective-method-cache (call-cache)
  (cadr call-cache))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Call history.
;;;
;;; We maintain a CALL HISTORY for each generic function.  The call
;;; history is a proper list, each element of which is a CALL CACHE.
;;;
;;; Different call caches in one call history may share the same
;;; applicable method cache and the same effective method cache.  When
;;; a new call cache C is about to be added to the call history, the
;;; existing call history is traversed to see whether there is an
;;; existing call cache D with the same (EQUAL) applicable method
;;; cache.  In this case, C is modified before it is added so that its
;;; applicable method cache and effective method cache are set to
;;; those of D.

;;; The discriminating function does the following:
;;;
;;;   1. Compute the list of instance class numbers of the required
;;;      arguments that it was passed and for which the specializer
;;;      profile contains T.
;;;
;;;   2. Compare each one of those to pre-computed constants using a
;;;      TAGBODY form.  If there is a hit, then the corresponding
;;;      effective method is invoked and the discriminating function
;;;      returns.
;;;
;;;   3. If there is not a hit, then control is transferred to the end
;;;      of the TAGBODY form.  There, DEFAULT-DISCRIMINATING-FUNCTION
;;;      is invoked.  
;;;
;;; The default discriminating function does the following:
;;;
;;;   1. Check that the instance class number of each specialized
;;;      required argument is the same as the unique number of its
;;;      class.  If it is not the case, call the generic function
;;;      UPDATE-INSTANCE-FOR-REDEFINED-CLASS on those arguments and
;;;      invoke the discriminating function again. 
;;;
;;;   2. If the instances are all up-to-date, then compute a call
;;;      profile for the call by calling CLASS-OF for each required
;;;      argument and then call the generic function
;;;      COMPUTE-APPLICABLE-METHODS-USING-CLASSES with the resulting
;;;      call profile.
;;;   
;;;   3. If the call in step 2 returns TRUE as a second return value,
;;;      then the first value returned represents an applicable method
;;;      cache to be stored.  If so, call the generic function
;;;      COMPUTE-EFFECTIVE-METHOD with applicable method cache, thus
;;;      computing an effective method cache.  Create a call cache
;;;      from the list computed in step 1, the applicable method
;;;      cache, and the effective method cache.  Add the computed call
;;;      cache to the call history.  Call the generic function
;;;      COMPUTE-DISCRIMINATING-FUNCTION in order to compute a new
;;;      discriminating function that takes into account the new
;;;      argument classes.  Finally, call the effective just computed
;;;      method and return the result.
;;;
;;;   4. If the call in step 2 returns FALSE as a second return value,
;;;      then instead call the generic function
;;;      COMPUTE-APPLICABLE-METHODS, passing it all the current
;;;      arguments.  
;;;
;;;   5. If the call in step 4 returns a non-empty list of methods,
;;;      then call COMPUTE-EFFECTIVE-METHOD with that list.  Call the
;;;      resulting effective method and return the result.
;;;
;;;   6. If the call in step 4 returns an empty list, then call
;;;      NO-APPLICABLE-METHOD.

;;; The implementation of this function is not complete.  Furthermore,
;;; this is probably not a good location for it.
(defun instance-class-number (instance)
  (if (heap-instance-p instance)
      (standard-instance-access instance 0)
      ;; For now, anything else is considered to be an instance of
      ;; class T, and we know that T has unique number 0.
      0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; How we make slot accessors fast.
;;;
;;; A slot accessor (reader or writer) generic function has methods on
;;; it that are instances of STANDARD-READER-METHOD and
;;; STANDARD-WRITER-METHOD.  Such methods have the moral meaning of
;;; (SLOT-VALUE <object> '<slot-name>) and 
;;; (SETF (SLOT-VALUE <object> '<slot-name>) <new-value>)
;;; where <object> and <new-value> are arguments of the generic function
;;; and <slot-name> is the name of the slot given by applying
;;; ACCESSOR-METHOD-SLOT-DEFINITION to the method metaobject.
;;;
;;; But SLOT-VALUE and (SETF SLOT-VALUE) must do a lot of work (though
;;; it is possible to speed it up), and we want the accessor to go
;;; directly to the slot location to make it fast.  The problem with
;;; that idea is that the slot location can be different in different
;;; subclasses of the class being specialized to, as given by applying
;;; METHOD-SPECIALIZERS to the methods.  It can even be an instance
;;; slot in some subclasses and shared slot in others.  
;;;
;;; We handle this situation by "cheating" in the discriminating
;;; function.  Once we have determined a list of applicable methods by
;;; calling COMPUTE-APPLICABLE-METHODS-USING-CLASSES, we make a pass
;;; over them and replace any accessor method by a newly created
;;; method that does the equivalent of (STANDARD-INSTANCE-ACCESS
;;; <object> <slot-location>), where <slot-position> is calculated by
;;; getting the name of the slot from the DIRECT-SLOT-DEFINITION
;;; stored in the accessor method, using CLASS-SLOTS on the class of
;;; <object> to find the EFFECTIVE slots of the class, then finding
;;; the slot with the right name, and finally getting its location by
;;; using SLOT-DEFINITION-LOCATION.

;;; This function takes a method and, if it is a standard reader
;;; method or a standard writer method, it replaces it with a method
;;; that does a direct instance access according to the relevant class
;;; in CLASSES.  Otherwise, it returns the METHOD argument unchanged.
(defun maybe-replace-method (method classes)
  (let ((method-class (class-of method)))
    (flet ((slot-location (direct-slot class)
	     (let* ((name (slot-definition-name direct-slot))
		    (effective-slots (effective-slots class))
		    (effective-slot (find name effective-slots
					  :key #'slot-definition-name
					  :test #'eq)))
	       (slot-definition-location effective-slot))))
      (cond ((eq method-class *standard-reader-method*)
	     (let* ((direct-slot (accessor-method-slot-definition method))
		    (location (slot-location direct-slot (car classes)))
		    (lambda-expression
		      `(lambda (arguments next-methods)
			 (declare (ignorable arguments next-methods))
			 ,(if (consp location)
			      `(car ',location)
			      `(standard-instance-access
				(car arguments) ,location)))))
	       (make-instance *standard-reader-method*
		 :qualifiers '()
		 :specializers (method-specializers method)
		 :lambda-list (method-lambda-list method)
		 :slot-definition direct-slot
		 :documentation nil
		 :function (compile nil lambda-expression))))
	    ((eq method-class *standard-writer-method*)
	     (let* ((direct-slot (accessor-method-slot-definition method))
		    (location (slot-location direct-slot (cadr classes)))
		    (lambda-expression
		      `(lambda (arguments next-methods)
			 (declare (ignorable arguments next-methods))
			 ,(if (consp location)
			      `(setf (car ',location)
				     (car arguments))
			      `(setf (standard-instance-access
				      (cadr arguments) ,location)
				     (car arguments))))))
	       (make-instance *standard-writer-method*
		 :qualifiers '()
		 :specializers (method-specializers method)
		 :lambda-list (method-lambda-list method)
		 :slot-definition direct-slot
		 :documentation nil
		 :function (compile nil lambda-expression))))
	    (t
	     method)))))

(defun final-methods (methods classes)
  (loop for method in methods
	collect (maybe-replace-method method classes)))

;;; This function can not itself be the discriminating function of a
;;; generic function, because it also takes the generic function
;;; itself as an argument.  However it can be called by the
;;; discriminating function, in which case the discriminating function
;;; must supply the GENERIC-FUNCTION argument either from a
;;; closed-over variable, from a compiled-in constant, or perhaps by
;;; some other mechanism.
(defun default-discriminating-function (generic-function arguments profile)
  (break)
  (let* ((required-argument-count (length profile))
	 (required-arguments (subseq arguments 0 required-argument-count))
	 (class-numbers (loop for argument in required-arguments
			      for p in profile
			      when p
				collect (instance-class-number argument)))
	 (entry (car (member class-numbers (call-history generic-function)
			     :key #'class-number-cache :test #'equal))))
    (unless (null entry)
      ;; Found an entry, call the effective method of the entry,
      ;; passing it the arguments we received.
      (return-from default-discriminating-function
	(apply (effective-method-cache entry) arguments)))
    ;; Come here if the call history did not contain an entry for the
    ;; current arguments.
    (let ((classes (mapcar #'class-of required-arguments))
	  (method-combination
	    (generic-function-method-combination generic-function)))
      (multiple-value-bind (applicable-methods ok)
	  (compute-applicable-methods-using-classes generic-function classes)
	(when ok
	  (let ((effective-method
		  (compute-effective-method
		   generic-function
		   method-combination
		   (final-methods applicable-methods classes))))
	    (push (make-call-cache class-numbers
				   applicable-methods
				   effective-method)
		  (call-history generic-function))
	    (return-from default-discriminating-function
	      (apply effective-method arguments))))
	;; Come here if we can't compute the applicable methods using
	;; only the classes of the arguments. 
	(let ((applicable-methods
		(compute-applicable-methods generic-function arguments)))
	  (when (null applicable-methods)
	    (apply #'no-applicable-method generic-function arguments))
	  (let ((effective-method
		  (compute-effective-method
		   generic-function
		   method-combination
		   (final-methods applicable-methods classes))))
	    (apply effective-method arguments)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Satiate a generic function.
;;;
;;; We assume we have a standard generic function.  We also assume
;;; that the specializers of each method are classes as opposed to EQL
;;; specializers.  Finally, we assume that the generic function uses
;;; the standard method combination.
;;;
;;; For each primary method of the generic function, compute all the
;;; combinations of argument classes that would make it applicable.
;;; Compute a unique list of such combinations of classes.  For each
;;; combination, do the same thing as is done of the generic function
;;; is actually called with those classes, i.e., compute the
;;; applicable methods and the effective method and load up the call
;;; history.  Finally, compute and set the discriminating function.

;;; Return all descendents of a class, including the class itself.
(defun all-descendents (class)
  (let ((subclasses (class-direct-subclasses class)))
    (remove-duplicates (cons class
			     (reduce #'append
				     (mapcar #'all-descendents subclasses))))))

(defun cartesian-product (sets)
  (if (null (cdr sets))
      (mapcar #'list (car sets))
      (loop for element in (car sets)
	    append (mapcar (lambda (set)
			     (cons element set))
			   (cartesian-product (cdr sets))))))

;;; CLASSES-OF-METHOD is a list of specializers (which much be classes)
;;; of a single method of the generic function.
(defun add-to-call-history (generic-function classes-of-method)
  (let* ((sets (loop for class in classes-of-method
		     collect (if (eq class *t*)
				 (list class)
				 (all-descendents class))))
	 (all-combinations (cartesian-product sets))
	 (mc (generic-function-method-combination generic-function)))
    (loop for combination in all-combinations
	  for methods = (compute-applicable-methods-using-classes
			 generic-function combination)
	  for em = (compute-effective-method
		    generic-function
		    mc
		    (final-methods methods combination))
	  for no-t = (remove *t* combination)
	  for numbers = (mapcar #'unique-number no-t)
	  do (unless (member numbers (call-history generic-function)
			     :key #'class-number-cache :test #'equal)
	       (push (make-call-cache numbers methods em)
		     (call-history generic-function))))))

(defun load-call-history (generic-function)
  (loop for method in (generic-function-methods generic-function)
	for specializers = (method-specializers method)
	do (add-to-call-history generic-function specializers)))

(defun satiate-generic-function (generic-function)
  (load-call-history generic-function)
  (let ((df (compute-discriminating-function generic-function)))
    (set-funcallable-instance-function generic-function df)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; To do: Meters.
;;;
;;; Generic function invocation is an excellent opportunity for
;;; Multics-style meters.
;;;
;;; For instance, we could record:
;;;
;;;  * Total number of calls.
;;;
;;;  * Number of calls resulting in a cache miss, so that a new
;;;    discriminating function must be computed.
;;;
;;;  * Total time computing a new discriminating function.
;;;
;;; With this information, we can compute some very interesting
;;; statistics, such as the average overhead per call as a result of
;;; computing a new discriminating function, etc.
