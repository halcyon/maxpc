;;;; Unit test cases.

(defpackage maxpc.test
  (:documentation
   "Test cases for MPC.")
  (:use :cl :maxpc :maxpc.char :maxpc.digit)
  (:export :run-tests))

(in-package :maxpc.test)

(defmacro passert (i p &optional (r 'result) (s 'match-p) (e 'end-p))
  `(multiple-value-bind (result match-p end-p)
       (parse ,i ,p)
     (assert ,r () "Failed assertion: ~a for RESULT = ~a" ',r result)
     (assert ,s () "Failed assertion: ~a for MATCH-P = ~a" ',s match-p)
     (assert ,e () "Failed assertion: ~a for END-P = ~a" ',e end-p)))

(defmacro passert-n (i p &optional (r '(null result))
                                   (s '(null match-p))
                                   (e '(null end-p)))
  `(multiple-value-bind (result match-p end-p)
       (parse ,i ,p)
     (assert ,r () "Failed assertion: ~a for RESULT = ~a" ',r result)
     (assert ,s () "Failed assertion: ~a for MATCH-P = ~a" ',s match-p)
     (assert ,e () "Failed assertion: ~a for END-P = ~a" ',e end-p)))

(defun test-end ()
  (passert "" (?end) (null result))
  (passert-n "f" (?end)))

(defun test-fail ()
  (passert-n "a" (?fail))
  (handler-case (parse "a" (?fail (error (make-instance 'parse-error))))
    (parse-error (e)
      (declare (ignore e)))
    (:no-error (e)
      (declare (ignore e))
      (error "=FAIL body was not run.")))
  (passert-n "a" (%maybe (?fail)) (null result) match-p)
  (passert "" (%maybe (=element)) (null result)))

(defun test-atom ()
  (passert-n "foo" (=element) (eq #\f result) match-p)
  (passert "" (=element) (null result) (null match-p)))

(defun test-satisfies ()
  (passert-n "foo" (?satisfies 'alpha-char-p)
             (null result) match-p)
  (passert-n "42" (?satisfies 'alpha-char-p))
  (passert-n "foo" (?eq #\f)
             (null result) match-p))

(defun test-subseq ()
  (passert-n "123" (=subseq (?satisfies 'digit-char-p))
             (equal result "1") match-p)
  (passert-n '(42 43) (=subseq (?satisfies 'numberp))
             (equal result '(42)) match-p)
  (passert-n "foo" (=subseq (?satisfies 'digit-char-p))
             (null result) (null match-p) (null end-p)))

(defun test-seq ()
  (passert "fo" (?seq (=element) (=element) (?end))
           (null result))
  (passert-n "foo" (?seq (=element) (=element) (?end)))
  (passert "fo" (?seq (?seq (?eq #\f) (=element)) (?end))
           (null result))
  (passert "" (?seq) (null result)))

(defun test-list ()
  (passert "fo" (=list (=element) (=element) (?end))
           (equal result '(#\f #\o nil)))
  (passert-n "foo" (=list (=element) (=element) (?end)))
  (passert "fo" (=list (?seq (?eq #\f) (=element)) (?end)))
  (passert "" (=list) (null result)))

(defun test-any ()
  (passert "" (%any (=element)) (null result) match-p)
  (passert-n "foo123" (=subseq (%any (?satisfies 'alpha-char-p)))
             (equal result "foo") match-p)
  (passert "" (%some (=element)) (null result) (null match-p))
  (passert "foo" (=list (%some (=element)) (?end))
           (equal result '((#\f #\o #\o) nil))))

(defun test-or ()
  (let ((fo (%or (?eq #\f) (?eq #\o))))
    (passert "fo" (=list fo fo (?end)))
    (passert-n "x" fo)
    (passert "" fo (null result) (null match-p))))

(defun test-and ()
  (let ((d (%and (?satisfies 'alphanumericp) (?satisfies 'digit-char-p))))
    (passert "12" (=list d d (?end)))
    (passert-n "f" (=list d (?end)))
    (passert-n "x1" (=list d d))))

(defun test-diff ()
  (let ((anp/c (%diff (?satisfies 'alphanumericp) (?eq #\c))))
    (passert "fo" (=list anp/c anp/c (?end)))
    (passert-n "c" (=list anp/c))
    (passert-n "ac" (=list anp/c anp/c)))
  (passert "f" (=list (?not (?end)) (?end))))

(defun test-transform ()
  (passert '(16) (=list (=transform (=element) '1+) (?end))
           (equal result '(17 nil)))
  (passert '(:a :b :c :d :e :f)
           (=destructure (a b c _ &rest e) (%any (=element))
             (append e (list c b a)))
           (equal result '(:e :f :c :b :a)))
  (passert '(:a :b)
           (=destructure (_ b) (=list (=element) (=element)))
           (equal result :b))
  (passert-n '(:a :b)
             (=destructure (_ b) (=list (?eq :c) (=element)))))

(defun test-interface ()
  (parse (format nil "fooza~%kar")
         (%or (?seq (?string "foo")
                    (?fail (assert (= 3 (get-input-position)))))
              (?seq (?string "fooza")
                    (?fail (assert (= 5 (get-input-position)))))
              (?seq (?string (format nil "fooza~%k"))
                    (?fail (assert (equal (multiple-value-list
                                           (get-input-position))
                                          '(7 2 2)))))))
  (passert "bar" (%handler-case (?fail (error "foo"))
                   (error () (?string "bar")))
           (null result))
  (passert "bar" (%restart-case
                     (%handler-case (?fail (error "foo"))
                       (error () (invoke-restart 'restart)))
                   (restart () (?string "bar")))
           (null result)))

(defun test-char ()
  (passert "λ" (?char #\λ) (null result))
  (passert "Λ" (?char #\λ nil) (null result))
  (passert "λδ" (?string "λδ") (null result))
  (passert "ΛΔ" (?string "λδ" nil) (null result))
  (passert (coerce *whitespace* 'string) (%any (?whitespace)) (null result))
  (passert (format nil "~%") (?newline) (null result))
  (passert (format nil "foo~%bar") (=list (=line) (=line t) (?end))
           (equal result (list "foo" (format nil "bar~%") nil))))

(defun test-digit ()
  (passert "f" (?digit 16) (null result))
  (passert "f423" (=natural-number 16) (= result #xf423))
  (passert "f423" (=integer-number 16) (= result #xf423))
  (passert "+f423" (=integer-number 16) (= result #xf423))
  (passert "-f423" (=integer-number 16) (= #x-f423))
  (passert-n "a1234" (=integer-number))
  (passert "1234a" (=integer-number) (= result 1234) match-p (null end-p)))

(defun run-tests ()
  (test-end)
  (test-fail)
  (test-atom)
  (test-satisfies)
  (test-subseq)
  (test-seq)
  (test-list)
  (test-any)
  (test-or)
  (test-and)
  (test-diff)
  (test-transform)
  (test-char)
  (test-digit)
  (test-interface))
