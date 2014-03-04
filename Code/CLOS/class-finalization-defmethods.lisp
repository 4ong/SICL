(cl:in-package #:sicl-clos)

(defmethod finalize-inheritance ((class regular-class))
  (finalize-inheritance-default class))

;;; This method should be removed once all built-in classes are
;;; finalized.
(defmethod finalize-inheritance ((class built-in-class))
  (finalize-built-in-inheritance class))

(defmethod compute-default-initargs ((class regular-class))
  (compute-default-initargs-default class))

(defmethod compute-slots :around ((class regular-class))
  (let ((slots (call-next-method)))
    (compute-slots-around-default slots)))

(defmethod compute-slots ((class regular-class))
  (compute-slots-default class))

(defmethod compute-effective-slot-definition ((class regular-class)
					      name
					      direct-slot-definitions)
  (compute-effective-slot-definition-default
   name
   direct-slot-definitions
   (effective-slot-definition-class class)))

(defmethod compute-class-precedence-list ((class class))
  (compute-class-precedence-list-default class))
