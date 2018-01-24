
(in-package :actors)

;; ----------------------------------------------------------------------------

;; ----------------------------------------------------------
;; Actors directory -- only for Actors with symbol names or string
;; names.
;;
;; This really ought to be an Actor-based manager! The directory is a
;; non-essential service during Actor base startup, so we will make it
;; an Actor-based service after all the base code is in place.

(defvar *actor-directory-manager* 'do-nothing)

(defun directory-manager-p ()
  (typep *actor-directory-manager* 'Actor))

        ;;; =========== ;;;

(defmethod acceptable-key (name)
  nil)

(defmethod acceptable-key ((name (eql nil)))
  nil)

(defmethod acceptable-key ((name symbol))
  (and (symbol-package name)
       (acceptable-key (string name))))

(defmethod acceptable-key ((name string))
  (string-upcase name))

        ;;; =========== ;;;

(defmethod register-actor ((actor actor) name)
  (when (acceptable-key name)
    (send *actor-directory-manager* :register actor name)))
  
(defun unregister-actor (name-or-actor)
  (send *actor-directory-manager* :unregister name-or-actor))

(defun get-recorded-actors ()
  (when (directory-manager-p)
    (ask *actor-directory-manager* :get-all)))

(defun find-actor-in-directory (name)
  (when (and (directory-manager-p)
             (acceptable-key name))
    (ask *actor-directory-manager* :find name)))

(defmethod find-actor-name ((actor actor))
  (when (directory-manager-p)
    (ask *actor-directory-manager* :reverse-lookup actor)))

(defmacro def-alias (sym fn-sym)
  `(setf (symbol-function ',sym) (symbol-function ',fn-sym)))

(def-alias get-actors get-recorded-actors)

(defmethod find-actor ((actor actor))
  actor)

(defun find-live-actor-in-directory (name)
  (find-actor (find-actor-in-directory name)))

(defmethod find-actor ((name string))
  (find-live-actor-in-directory name))

(defmethod find-actor ((name symbol))
  (find-live-actor-in-directory name))

(defmethod find-actor ((actor (eql nil)))
  nil)

(defun install-actor-directory ()
  (setf *actor-directory-manager*
        (make-actor
            (let ((directory
                   #+:LISPWORKS
                   (make-hash-table
                    :test 'equal
                    :single-thread t)
                   #+:ALLEGRO
                   (make-hash-table
                    :test 'equal))
                  (rev-directory
                   #+:LISPWORKS
                   (make-hash-table
                    :test 'eq
                    :single-thread t)
                   #+:ALLEGRO
                   (make-hash-table
                    :test 'eq)))
              
              (labels ((clean-up ()
                         (setf *actor-directory-manager* 'do-nothing)))
                
                (dlambda
                  (:clear ()
                   (clrhash directory))
                  
                  (:register (actor name)
                   ;; this simply overwrites any existing entry with actor
                   (when-let (key (acceptable-key name))
                     (setf (gethash key directory) actor
                           (gethash actor rev-directory) key)))
                  
                  (:unregister (name-or-actor)
                   (cond ((typep name-or-actor 'Actor)
                          (when-let (key (gethash name-or-actor rev-directory))
                            (remhash key directory)
                            (remhash name-or-actor rev-directory)))
                         (t
                          (when-let (key (acceptable-key name-or-actor))
                            (when-let (actor (gethash key directory))
                              (remhash key directory)
                              (remhash actor rev-directory))))
                         ))
                  
                  (:get-all ()
                   (let (actors)
                     (maphash (lambda (k v)
                                (setf actors (acons k v actors)))
                              directory)
                     (sort actors #'string-lessp :key #'car)))
                  
                  (:find (name)
                   (um:when-let (key (acceptable-key name))
                     (gethash key directory)))
                  
                  (:reverse-lookup (actor)
                   (gethash actor rev-directory))
                  
                  (:quit ()
                   (clean-up))
                  )))))
  (register-actor *actor-directory-manager* :ACTOR-DIRECTORY)
  (pr "Actor Directory created..."))

;; --------------------------------------------------------
;; Shared printer driver... another instance of something better
;; placed into an Actor

(defun blind-print (cmd &rest items)
  (declare (ignore cmd))
  (dolist (item items)
    (print item)))

(defvar *shared-printer-actor*    #'blind-print)

(defun pr (&rest things-to-print)
  (apply #'send *shared-printer-actor* :print things-to-print))

(defun install-actor-printer ()
  (setf *shared-printer-actor*
        (make-actor
          (dlambda
            (:print (&rest things-to-print)
             (dolist (item things-to-print)
               (print item)))
            
            (:quit ()
             (setf *shared-printer-actor* #'blind-print))
            )))
  (register-actor *shared-printer-actor* :SHARED-PRINTER))

;; --------------------------------------------------------

(defun install-actor-system (&rest ignored)
  (declare (ignore ignored))
  (install-actor-directory)
  (install-actor-printer))

#+:ALLEGRO
(install-actor-system)

#||#
#+:LISPWORKS
(let ((lw:*handle-existing-action-in-action-list* '(:silent :skip)))
  
  (lw:define-action "Initialize LispWorks Tools"
                    "Start up Functional Actors"
                    'install-actor-system
                    :after "Run the environment start up functions"
                    :once))
#||#
