(in-package #:sicl-boot-phase2)

(shadowing-import '(define-built-in-class)
		  '#:sicl-array)

(unintern 'cl:array-dimensions '#:sicl-array)

(shadow '(#:array-dimensions)
	'#:sicl-array)
