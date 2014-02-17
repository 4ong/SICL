(cl:in-package #:sicl-clos)

;;; Implement class initialization according to the section of the
;;; AMOP entitled "Initialization of Class Metaobjects".

;;; For :direct-default-initargs, the AMOP says that it defaults to
;;; the empty list when the class metaobject is being initialized.  We
;;; take that to implicitly imply that when the class metaobject is
;;; reinitialized as opposed to initialized, there is no default for
;;; this initialization argument, so that if it is not given, the old
;;; value is retained.  The AMOP furthermore says that this argument
;;; is a list of canonicalized default initialization arguments.  The
;;; canonicalization is accomplished directly in the DEFCLASS macro
;;; (it has to, because a closure needs to be created there to get the
;;; lexical environment right), so there is no further processing to
;;; be done after that.  It follows that we can obtain the desired
;;; effect by using an :initform in the definition of the class.

;;; For :direct-slots, the situation is more complicated.  the
;;; DEFCLASS macro provides us with the canonicalized
;;; slot-descriptions, but it can not create the
;;; DIRECT-SLOT-DEFINITION metaobjects, because the class to be used
;;; for those metaobjects is determined later.  During initialization
;;; and reinitialization, there is therefore some further processing
;;; that needs to be done.  Again, the AMOP says that it defaults to
;;; the empty list when the class metaobject is being initialized.
;;; Again, we take that to implicitly imply that when the class
;;; metaobject is reinitialized as opposed to initialized, there is no
;;; default for this initialization argument, so that if it is not
;;; given, the old value is retained.

;;; Provide an :after method on INITIALIZE-INSTANCE to be used
;;; when class meta-objects are instantiated.  As the AMOP says,
;;; we have to provide appropriate default values for the superclasses
;;; and we have to link the superclasses to this new class meta-object.
;;; We also have to create slot meta-objects from the slot property
;;; list provided to initialize-instance.

;;; The AMOP is not quite clear when it comes to restrictions on
;;; portable programs with respect to methods on INITIALIZE-INSTANCE
;;; and REINITIALIZE-INSTANCE.  It explicitly allows for portable
;;; programs to define :before and :after methods on
;;; INITIALIZE-INSTANCE, so one might think that the implementation
;;; could not define an :after method on INITIALIZE-INSTANCE because
;;; it could be overridden by a perfectly good portable program.  But
;;; then, when reading the restriction about :around methods (it says
;;; it must be EXTENDING, not OVERRIDING) it seems clear that the
;;; :before, :after, and :around methods that a portable program is
;;; allowed to define specialize for STRICT SUBCLASSES of the standard
;;; classes, so we are safe if we define an :after method in
;;; INITIALIZE-INSTANCE here. 

(defun check-direct-default-initargs (direct-default-initargs)
  ;; FIXME: check that the elements of the list are canonicalized
  ;; default initargs.
  (unless (proper-list-p direct-default-initargs)
    (error "direct default initargs must be a proper list")))

(defun check-direct-superclasses (class direct-superclasses)
  (unless (proper-list-p direct-superclasses)
    (error "direct superclasses must be proper list"))
  (loop for direct-superclass in direct-superclasses
	do (unless (classp direct-superclass)
	     (error "superclass must be a class metaobject"))
	   (unless (validate-superclass class direct-superclass)
	     (error "superclass not valid for class"))))

(defun check-and-instantiate-direct-slots (class direct-slots)
  (unless (proper-list-p direct-slots)
    (error "direct slots must be proper list"))
  ;; FIXME: check that the elements are canonicalized slot specifications
  (loop for canonicalized-slot-specification in direct-slots
	collect (apply #'make-instance
		       (apply #'direct-slot-definition-class
			      class canonicalized-slot-specification)
		       canonicalized-slot-specification)))

(defun add-as-subclass-to-superclasses (class)
  (loop for superclass in (class-direct-superclasses class)
	do (setf (c-direct-subclasses superclass)
		 (cons class (class-direct-subclasses superclass)))))

(defun create-readers-and-writers (class direct-slots)
  (loop for direct-slot in direct-slots
	do (loop for reader in (slot-definition-readers direct-slot)
		 do (add-reader-method class reader direct-slot))
	   (loop for writer in (slot-definition-writers direct-slot)
		 do (add-writer-method class writer direct-slot))))

(defun initialize-instance-after-common (class direct-slots)
  (add-as-subclass-to-superclasses class)
  (create-readers-and-writers class direct-slots))

(defun initialize-instance-after-standard-class-default
    (class &key direct-slots &allow-other-keys)
  (initialize-instance-after-common class direct-slots))

(defun initialize-instance-after-funcallable-standard-class-default
    (class &key direct-slots &allow-other-keys)
  (initialize-instance-after-common class direct-slots))

;;; According to the AMOP, calling initialize-instance on a built-in
;;; class (i.e., on an instance of a subclass of the class
;;; BUILT-IN-CLASS) signals an error, because built-in classes can not
;;; be created by the user.  But during the bootstrapping phase we
;;; need to create built-in classes.  We solve this problem by
;;; removing this method once the bootstrapping phase is finished.
;;;
;;; We do not add readers and writers here, because we do it in
;;; ENSURE-BUILT-IN-CLASS after we have finalized inheritance.  The
;;; reason for that is that we then know the slot location.
(defun initialize-instance-after-built-in-class-default
    (class &key direct-slots &allow-other-keys)
  (add-as-subclass-to-superclasses class))
