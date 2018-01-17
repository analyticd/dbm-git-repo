;; AONT Messaging delivery script
;;
#|;; To use:

;; For Mac-64
pushd /Applications/LispWorks\ 7.0\ \(64-bit\)/LispWorks\ \(64-bit\).app/Contents/MacOS
# ./Lispworks-7-0-0-amd64-darwin -build ~/projects/lispworks/Crypto/deliver-aont.lisp
./Lispworks-7-0-0-amd64-darwin -build ~/projects/lispworks/Crypto/deliver-aont.lisp
popd

;; For Mac
pushd /Applications/LispWorks\ 6.0/LispWorks.app/Contents/MacOS
./Lispworks-6-0-0-macos-universal -init ~/projects/lispworks/Godzilla/deliver.lisp
popd

;; for Windows (Dawson)
pushd h:/projects/Lispworks
"d:/program Files/Lispworks/lispworks-5-1-0-x86-win32.exe" -init ./Godzilla/deliver.lisp

;; for Vista (Slate)
pushd c:/Users/Public/projects/Lispworks
"c:/program Files/Lispworks/lispworks-5-1-0-x86-win32.exe" -init ./Godzilla/deliver.lisp

;; for Vista (Citrine-Vista & Topaz-Vista)
pushd c:/projects/Lispworks
"c:/program Files/Lispworks/lispworks-7-0-0-x64-windows.exe" -init ./VTuning/crypto/tools/deliver-aont.lisp
popd

|#

(load-all-patches)

#+:MACOSX
(let ((prjdir "/Volumes/My Passport for Mac/projects"))
  (setf (environment-variable "PROJECTS")
	(if (probe-file prjdir)
	    prjdir
	    (namestring #P"~/projects"))))

(load-logical-pathname-translations "PROJECTS")
(change-directory (translate-logical-pathname "PROJECTS:LISP;"))

(load "dongle")

(let ((mi (machine-instance)))
  (cond ((string-equal "CITRINE-VISTA" mi) (load "Win32-Citrine-ASDF-Starter"))
	((string-equal "SLATE"         mi) (load "Win32-Citrine-ASDF-Starter"))
        ((string-equal "TOPAZ-VISTA"   mi) (load "Win32-Topaz-ASDF-Starter"))
        ((string-equal "DAWSON"        mi) (load "Win32-Dawson-ASDF-Starter"))
        ((string-equal "RAMBO"         mi) (load "Win32-Citrine-ASDF-Starter"))
        (t                                 (load "ASDF-Starter"))
        ))

;; ------------------------------------------------------------------------------
;; Get the bundle maker for OS X

#+:MACOSX
(compile-file-if-needed "macos-application-bundle" :load t)

;; ------------------------------------------------------------------------------
;; Get the components we need in the base Lisp

#+:WIN32 (require "ole")
(require "mt-random")

;; ------------------------------------------------------------------------------
;; Compile the application
;; (asdf:operate 'asdf:load-op :godzilla :force t) ;; force full recompile
;; (asdf "butterfly")
(asdf "aont")

(require "inspector-values")

;; ------------------------------------------------------------------------------
;; Change to the resources folder

;; (change-directory (translate-logical-pathname "PROJECTS:LISP;godzilla;"))

(deliver 'ecc-crypto-b571::make-aont-messaging-intf 

         #+:MACOSX
         (let ((this-dir (translate-logical-pathname "PROJECTS:LISP;Crypto;")))
           (write-macos-application-bundle
            "/Applications/Tolstoy-AONT.app"
            :signature  "ACUD"
            :identifier "com.ral.aont"
            :application-icns (merge-pathnames "calculator.icns" this-dir)
            :document-types nil))

	 #+:WIN32 "Tolstoy-AONT.exe"
         
         0 ;; delivery level
         
         ;; #+:WIN32 :icon-file #+:WIN32 "Resources/Godzilla.png"

         :multiprocessing t
         :interface :capi
         :keep-lisp-reader t
         ;; :keep-conditions :all
         :quit-when-no-windows t
         :kill-dspec-table nil
         ;; :keep-pretty-printer t

         :keep-editor t
         :editor-style #+:MACOSX :mac #+:WIN32 :pc
         ;; :editor-style :emacs
         ;; :keep-complex-numbers t
         ;; :keep-eval t
         ;; :keep-load-function t
         ;; :keep-modules t
         ;; :keep-package-manipulation t
         ;; :keep-trans-numbers t
         ;; :redefine-compiler-p nil
         
         ;; :keep-foreign-symbols t
	 ;; :keep-gc-cursor t

	 :versioninfo
         (list
          :binary-version #x0001000100000010
	  :version-string "Version 1.01 build 16"
	  :company-name   "Refined Audiometrics Laboratory, LLC"
	  :product-name   "AONT"
	  :file-description "Use to encode / decode AONT messages"
          :legal-copyright  "Copyright (c) 2015 by Refined Audiometrics Laboratory, LLC. All rights reserved.")
	 ;; :keep-debug-mode t
	 ;; :packages-to-keep :all

         :startup-bitmap-file nil
         )
(quit)
