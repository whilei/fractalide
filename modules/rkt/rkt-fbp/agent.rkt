#lang typed/racket

; TODO : what to do with unconnected output port?

(provide (struct-out agent)
         (struct-out opt-agent)
         recv
         send
         agent-connect
         agent-connect-to-array
         agent-connect-array-to
         make-agent)

(require fractalide/modules/rkt/rkt-fbp/port)

(define-type in-array-port
  (Immutable-HashTable String (cons Integer port)))

(define-type out-array-port
  (Immutable-HashTable String port))

(struct agent([inport : (Immutable-HashTable String port)]
              [in-array-port : (Immutable-HashTable String in-array-port)]
              [outport : (Immutable-HashTable String (U False port))]
              [out-array-port : (Immutable-HashTable String out-array-port)]
              [proc : (-> agent Void)]
              [sched : Thread]) #:transparent)

(struct opt-agent([inport : (Listof String)]
                  [in-array : (Listof String)]
                  [outport : (Listof String)]
                  [out-array : (Listof String)]
                  [proc : (-> agent Void)]) #:transparent)

;;
;; Methods for using the agent
;;

(: recv (-> agent String Any))
(define (recv agent port)
  (port-recv (hash-ref (agent-inport agent) port)))

(: send (-> agent String Any Void))
(define (send agent port msg)
  (let ([out-port (hash-ref (agent-outport agent) port)])
    (if out-port
        (port-send out-port msg)
        (void))))


;;
;; Methods for manipulate the agent
;;

; Connect
(: agent-connect (-> agent String port agent))
(define (agent-connect self port sender)
  (let* ([out (agent-outport self)]
        [new-port (hash-set out port sender)])
    (struct-copy agent self [outport new-port])))

; Connect-to-array
; It retrieve the Sender from an input port
(: agent-connect-to-array (-> agent String String String Thread (values port agent)))
(define (agent-connect-to-array self port selection name sched)
  (let* ([in (agent-in-array-port self)]
         [array (hash-ref in port)]
         [selec (hash-ref array selection #f)])
    (if selec
        ; Already existing, add 1 and return
        (let* ([sender (cdr selec)]
               [new-selec (cons (+ (car selec) 1) sender)]
               [new-array (hash-set array selection new-selec)]
               [new-in (hash-set in port new-array)]
               [new-agent (struct-copy agent self [in-array-port new-in])])
          (values sender new-agent))
        ; Not yet existing, set at 1, create and return
        (let* ([sender (make-port 30 name sched)]
               [new-selec (cons 1 sender)]
               [new-array (hash-set array selection new-selec)]
               [new-in (hash-set in port new-array)]
               [new-agent (struct-copy agent self [in-array-port new-in])])
          (values sender new-agent)))))

; Connect-array-to
; It set a sender to an array output port
(: agent-connect-array-to (-> agent String String port agent))
(define (agent-connect-array-to self port selection sender)
  (let* ([out (agent-out-array-port self)]
         [array (hash-ref out port)]
         [new-array (hash-set array selection sender)]
         [new-out (hash-set out port new-array)])
    (struct-copy agent self [out-array-port new-out])
    )
  )

; disconnect
; disconnect-to-array
; disconnect-array-to

;;
;; Methods for building the agent
;; privates
;;

(: build-inport (-> (Listof String) String Thread (Immutable-HashTable String port)))
(define (build-inport inputs name sched)
  (for/hash: : (Immutable-HashTable String port) ([input inputs])
    (values input (make-port 30 name sched))))

(: build-outport (-> (Listof String) (Immutable-HashTable String False)))
(define (build-outport outputs)
  (for/hash: : (Immutable-HashTable String False) ([output outputs])
    (values output #f)))

(: build-in-array-port (-> (Listof String) (Immutable-HashTable String in-array-port)))
(define (build-in-array-port inputs)
  (for/hash: : (Immutable-HashTable String in-array-port) ([input inputs])
    (let ([empty : in-array-port (make-immutable-hash)])
      (values input empty))))

(: build-out-array-port (-> (Listof String) (Immutable-HashTable String out-array-port)))
(define (build-out-array-port inputs)
  (for/hash: : (Immutable-HashTable String out-array-port) ([input inputs])
    (let ([empty : out-array-port (make-immutable-hash)])
      (values input empty))))
;;
;; The method to create an agent
;;

(: make-agent (-> opt-agent String Thread agent))
(define (make-agent opt name sched)
  (agent
   (build-inport (opt-agent-inport opt) name sched)
   (build-in-array-port (opt-agent-in-array opt))
   (build-outport (opt-agent-outport opt))
   (build-out-array-port (opt-agent-out-array opt))
   (opt-agent-proc opt)
   sched)) ;TODO check if useful