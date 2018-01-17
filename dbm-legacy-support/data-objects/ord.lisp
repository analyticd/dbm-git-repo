;; ord.lisp
;; --------------------------------------------------------------------------------------
;; Compare ordering of various types
;;
;; Copyright (C) 2008 by Refined Audiometrics Laboratory, LLC. All rights reserved.
;;
;; DM/RAL  08/08
;; --------------------------------------------------------------------------------------

;; ------------------------------------------------------------------------
(in-package :ord)
;; ------------------------------------------------------------------------

(defun equal (a b)
  (zerop (compare a b)))

(defun less (a b)
  (minusp (compare a b)))

(defun greater (a b)
  (plusp (compare a b)))

;; ---------------------------------------------

(defmethod compare ((a real) (b real))
  #f
  (- a b))

(defmethod compare ((a character) (b character))
  #f
  (- (char-code a) (char-code b)))

(defmethod compare ((a symbol) (b symbol))
  #f
  (let ((pa (symbol-package a))
        (pb (symbol-package b)))
    (if (eq pa pb)
        (compare (symbol-name a) (symbol-name b))
      ;; else
      (let ((c (compare (package-name pa) (package-name pb))))
        (if (zerop c)
            (compare (symbol-name a) (symbol-name b))
          c))
      )))

(defmethod compare ((a pathname) (b pathname))
  #f
  (compare (namestring a) (namestring b)))

(defstruct ci-char
  c)

(defmethod compare ((a ci-char) (b ci-char))
  #f
  (- (char-code (char-upcase (ci-char-c a)))
     (char-code (char-upcase (ci-char-c b)))))

(defstruct ci-string
  s)

(defmethod compare ((a ci-string) (b ci-string))
  #f
  (compare (string-upcase (ci-string-s a))
           (string-upcase (ci-string-s b))))

(defmethod compare ((a vector) (b vector))
  #f
  (let* ((nela (length a))
         (nelb (length b))
         (nel  (min nela nelb)))
    (um:nlet-tail iter ((ix 0))
      (if (>= ix nel)
          (- nela nelb)
        ;; else
        (let ((c (compare (aref a ix) (aref b ix))))
          (if (zerop c)
              (iter (1+ ix))
            c))
        ))))

(defmethod compare ((a list) (b list))
  #f
  (um:nlet-tail iter ((a a)
                      (b b))
    (cond ((endp a)
           (if (endp b)
               0
             -1))

          ((endp b) 1)

          (t
           (let ((c (compare (car a) (car b))))
             (if (zerop c)
                 (iter (cdr a) (cdr b))
               c)))
          )))

;; ------------------------------------------

(defun compare< (a b)
  #f
  (minusp (the fixnum (compare a b))))

(defun compare<= (a b)
  #f
  (not (plusp (the fixnum (compare a b)))))

(defun compare= (a b)
  #f
  (zerop (the fixnum (compare a b))))

(defun compare>= (a b)
  #f
  (not (minusp (the fixnum (compare a b)))))

(defun compare> (a b)
  #f
  (plusp (the fixnum (compare a b))))

;; ------------------------------------------

(defun minval (&rest args)
  (reduce (lambda (a b)
            (if (compare< a b)
                a
              b))
          args))

(defun maxval (&rest args)
  (reduce (lambda (a b)
            (if (compare> a b)
                a
              b))
          args))

;; ------------------------------------------------------------------------
#|
(defmethod compare= (a b)
  (eql a b))

(defmethod compare= ((a number) (b number))
  (= a b))

(defmethod compare= ((a string) (b string))
  (string= a b))

(defstruct string-ci
  str)

(defmethod compare= ((a string-ci) (b string-ci))
  (string-equal (string-ci-str a) (string-ci-str b)))

(defmethod compare= ((a character) (b character))
  (char= a b))

(defstruct char-ci
  char)

(defmethod compare= ((a char-ci) (b char-ci))
  (char-equal (char-ci-char a) (char-ci-char b)))

(defmethod compare= ((a pathname) (b pathname))
  (pathname-match-p a b))

(defmethod compare= ((a list) (b list))
  (cond ((null a) (null b))
        ((null b) nil)
        (t        (and (compare= (first a) (first b))
                       (compare= (rest a)  (rest b))))
        ))

(defmethod compare= ((a array) (b array))
  (and (= (array-rank a) (array-rank b))
       (every '= (array-dimensions a) (array-dimensions b))
       (eql (adjustable-array-p a) (adjustable-array-p b))
       (eql (array-element-type a) (array-element-type b))
       (every 'compare=
              (make-array (array-total-size a)
                          :element-type (array-element-type a)
                          :displaced-to a
                          :displaced-index-offset 0)
              (make-array (array-total-size b)
                          :element-type (array-element-type b)
                          :displaced-to b
                          :displaced-index-offset 0))
       ))

(defmethod compare= ((a vector) (b vector))
  (and (= (length a) (length b))
       (eql (array-element-type a) (array-element-type b))
       (eql (adjustable-array-p a) (adjustable-array-p b))
       (eql (fill-pointer a) (fill-pointer b))
       (every 'compare= a b)))
|#
;; ------------------------------------------------------------------------

