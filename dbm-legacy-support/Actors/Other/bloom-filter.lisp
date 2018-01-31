;; hashed-sync.lisp -- Synchronizing large data sets across a network
;; with refined hashing probes
;;
;; DM/RAL 11/17
;; ----------------------------------------------------------------------

(defpackage #:bloom-filter
  (:use #:common-lisp)
  (:import-from #:um
   #:nlet-tail
   #:if-let
   #:when-let
   #:group
   #:dlambda
   #:foreach)
  (:export
   #:make-bloom-filter
   #:hash32
   #:add-obj-to-bf
   #:test-obj-hash
   #:test-membership
   ))


;; -----------------------------------------------------------------------

(user::asdf :sha3)

(in-package #:bloom-filter)

;; equiv to #F
(declaim  (OPTIMIZE (SPEED 3) (SAFETY 0) #+:LISPWORKS (FLOAT 0)))

;; -----------------------------------------------------------------------

(defun hash32 (obj)
  (let ((seq (loenc:encode obj))
        (dig (ironclad:make-digest :sha256)))
    (ironclad:update-digest dig seq)
    (ironclad:produce-digest dig)))

(defun hash64 (obj)
  ;; Q&D good for stringable args only (strings, symbols)
  (let ((seq (loenc:encode obj))
        (state (sha3:sha3-init :output-bit-length 512)))
    (sha3:sha3-update state seq)
    (sha3:sha3-final state)))

;; --------------------------------------------------------------------------
;; Bloom Filter... Is this item a member of a set? No false negatives,
;; but some false positives.
;;
;; Optimal sizing: For N items, we need M bits per item, and K hashing
;; algorithms, where, for false positive rate p we have:
;;
;;  M = -1.44 N Log2 p
;;  K = -Log2 p
;;
;; So, for N = 1000, p < 1%, we have M = 10 N = 10,000 bits, and K = 7
;;
;; We can use successive octets of a SHA256 hash to provide the K hash
;; functions. Since we need 10,000 bits in the table, round that up to
;; 16384 bits = 2^14, so we need 14 bits per hash, make that 2 octets
;; per hash. We need 7 hashes, so that is 14 octets from the SHA256
;; hash value, which offers 32 octets. That's doable....
;;
;; Unfortunately... this mechanism is only applicable to sets as
;; collections without duplicate items. Linda expressly allows
;; duplicate data in its datastore. So this is only a partial solution
;; to keeping tuple-spaces synchronized.
;;
;; This is not a problem for missing items. If an item is found
;; missing from the other data store, then it and all duplicates will
;; be transfered across. The problem arises only for items already in
;; the other data store. We can't keep items in common up to matching
;; duplication levels using Bloom filters.

(defclass bloom-filter ()
  ((bf-nitems  ;; number of items this filter designed for
    :reader  bf-nitems
    :initarg :nitems)
   (bf-pfalse  ;; probability of false positives 
    :reader  bf-pfalse
    :initarg :pfalse)
   (bf-k       ;; number of hashings needed
    :reader  bf-k
    :initarg :bf-k)
   (bf-m       ;; number of bits in table
    :reader  bf-m
    :initarg :bf-m)
   (bf-ix-octets  ;; number of octets needed per hashing key
    :reader  bf-ix-octets
    :initarg :bf-ix-octets)
   (bf-hash
    :reader  bf-hash ;; hash function needed
    :initarg :bf-hash)
   (bf-bits       ;; actual bit table
    :accessor bf-bits
    :initarg  :bf-bits)))

(defun pfalse (n k m)
  (expt (- 1d0 (expt (- 1d0 (/ m)) (* k n))) k))

#|
(plt:fplot 'pfalse '(1 20) (lambda (k)
                             (pfalse #N100 k #N2_000))
           :clear t
           :title "Bloom Filter P_false"
           :xtitle "K"
           :ytitle "P_false"
           :ylog t)
|#

(defun make-bloom-filter (&key (pfalse 0.01) (nitems #N1_000))
  (let* ((bf-k         (ceiling (- (log pfalse 2))))
         (bf-m         (um:ceiling-pwr2 (ceiling (* -1.44 nitems (log pfalse 2)))))
         (bf-ix-octets (ceiling (um:ceiling-log2 bf-m) 8))
         (bf-hash      (if (> (* bf-ix-octets bf-k) 32)
                           'hash64
                         'hash32)))
    (assert (<= (* bf-ix-octets bf-k) 64))
    (make-instance 'bloom-filter
                   :nitems  nitems
                   :pfalse  pfalse
                   :bf-k    bf-k
                   :bf-m    bf-m
                   :bf-ix-octets bf-ix-octets
                   :bf-hash bf-hash
                   :bf-bits (make-array bf-m
                                        :element-type 'bit
                                        :initial-element 0))
    ))

(defun compute-bix (bf hv ix)
  ;; bf points to Bloom Filter
  ;; hv is SHA32 hash octets vector
  ;; ix is starting offset into octents vector
  (mod
   (loop repeat (bf-ix-octets bf)
         for jx from 0
         for nsh from 0 by 8
         sum
         (ash (aref hv (+ ix jx)) nsh))
   (bf-m bf)))
  
(defmethod add-obj-to-bf ((bf bloom-filter) obj)
  (let ((hv  (funcall (bf-hash bf) obj)))
    (loop repeat (bf-k bf)
          for ix from 0 by (bf-ix-octets bf)
          do
          (let ((bix (compute-bix bf hv ix)))
            (setf (aref (bf-bits bf) bix) 1)))
    hv))

(defmethod test-obj-hash ((bf bloom-filter) hash)
  (loop repeat (bf-k bf)
        for ix from 0 by (bf-ix-octets bf)
        do
        (let ((bix (compute-bix bf hash ix)))
          (when (zerop (aref (bf-bits bf) bix))
            (return nil)))
        finally (return :maybe)))

(defmethod test-membership ((bf bloom-filter) obj)
  (test-obj-hash bf (funcall (bf-hash bf) obj)))

#|
(let ((x1  '(1 2 :a 43 (a b c)))
      (x2  '(1 :a 43 3 (d e f)))
      (bf  (make-bloom-filter)))
  (um:lc ((:do
              (add-obj-to-bf bf obj))
          (obj <- x1)))
  (inspect bf)
  (um:lc ((test-membership bf obj)
          (obj <- x2))))
  
 |#
;; ---------------------------------------------------------
#|
(linda:on-rdp ((:full-dir-tree ?t))
  (let* ((all (um:accum acc
                (maps:iter (lambda (k v)
                             (acc (cons k v)))
                           ?t)))
         (nel (length all))
         (bf  (make-bloom-filter :nitems nel))
         (hashes (um:accum acc
                   (dolist (file all)
                     (acc (add-obj-to-bf bf file))))))

    (linda:remove-tuples '(:all-files-bloom-filter ?x))
    (linda:remove-tuples '(:all-files ?x))
    (linda:remove-tuples '(:all-files-hashes ?x))
    
    (linda:out `(:all-files-bloom-filter ,bf))
    (linda:out `(:all-files ,all))
    (linda:out `(:all-files-hashes ,hashes))))

;; for use on Dachshund
(progn
  (linda:remove-tuples '(:other-bloom-filter ?x))
  (linda:out `(:other-bloom-filter
               ,(car (linda:remote-srdp '(:all-files-bloom-filter ?bf)
                                        "malachite.local")))))

;; for use on Malachite
(progn
  (linda:remove-tuples '(:other-bloom-filter ?x))
  (linda:out `(:other-bloom-filter
               ,(car (linda:remote-srdp '(:all-files-bloom-filter ?bf)
                                        "dachshund.local")))))

(let* ((other-bf  (car (linda:srdp '(:other-bloom-filter ?bf))))
       (hashes    (car (linda:srdp '(:all-files-hashes ?hashes))))
       (files     (car (linda:srdp '(:all-files ?files))))
       (diffs     (um:accum acc
                    (um:foreach (lambda (hash file)
                                  (unless (test-obj-hash other-bf hash)
                                    (acc (car file))))
                                hashes files))))
  (with-standard-io-syntax
    (pprint diffs))
  diffs)
|#
;; ---------------------------------------------------------
