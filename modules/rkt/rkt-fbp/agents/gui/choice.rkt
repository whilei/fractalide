#lang racket/base

(provide agt)

(require fractalide/modules/rkt/rkt-fbp/agent
         fractalide/modules/rkt/rkt-fbp/agents/gui/helper)


(require racket/gui/base
         racket/match)
(require (prefix-in class: racket/class))

(define base-default
  (hash 'label #f
        'choices '()
        'selection 0
        'style '()
        'font normal-control-font
        'enabled #t
        'vert-margin 2
        'horiz-margin 2
        'min-width #f
        'min-height #f
        'stretchable-width #f
        'stretchable-height #f))

(define (generate input data)
  (lambda (frame)
    (define default (for/fold ([acc base-default])
                              ([d data])
                      (hash-set acc (car d) (cdr d))))
    (let* ([cb (class:new (with-event choice% input) [parent frame]
                          [label (hash-ref default 'label)]
                          [choices (hash-ref default 'choices)]
                          [selection (hash-ref default 'selection)]
                          [style (hash-ref default 'style)]
                          [font (hash-ref default 'font)]
                          [enabled (hash-ref default 'enabled)]
                          [vert-margin (hash-ref default 'vert-margin)]
                          [horiz-margin (hash-ref default 'horiz-margin)]
                          [min-width (hash-ref default 'min-width)]
                          [min-height (hash-ref default 'min-height)]
                          [stretchable-width (hash-ref default 'stretchable-width)]
                          [stretchable-height (hash-ref default 'stretchable-height)]
                          [callback (lambda (button event)
                                      (send (input "in") (cons (class:send event get-event-type)
                                                               (class:send button get-string-selection))))])])
      (send (input "acc") cb))))

(define (process-msg msg widget input output output-array)
  (define managed #f)
  (set! managed (area-manage widget msg output output-array))
  (set! managed (subarea-manage widget msg output output-array))
  (set! managed (window-manage widget msg output output-array))
  (set! managed (list-control-manage widget msg output output-array))
  (if managed
      (void)
      (send-action output output-array msg)))


(define agt
  (define-agent
    #:input '("in") ; in port
    #:output '("out") ; out port
    #:output-array '("out")
    #:proc
    (lambda (input output input-array output-array)
      (define acc (try-recv (input "acc")))
      (define msg (recv (input "in")))
      (set! acc (manage acc msg input output output-array generate process-msg))
      (send (output "acc") acc))))