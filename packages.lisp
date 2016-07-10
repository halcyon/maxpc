(defpackage maxpc.input
  (:documentation
   "The generic _input_ interface allows extensions to parse other _types_ of
    _input sources_. To add a new _input source type_, {make-input} has to be
    specialized on that _type_. The following methods have to be defined for
    _inputs_:

    + {input-empty-p}
    + {input-first}
    + {input-rest}

    The following methods can optionally defined for _inputs_:

    + {input-position}
    + {input-element-type}
    + {input-sequence}")
  (:use :cl)
  (:export :make-input
           :input-position
           :input-element-type
           :input-empty-p
           :input-first
           :input-rest
           :input-sequence))

(defpackage maxpc
  (:documentation
   "_Max’s Parser Combinators_¹ is a simple and pragmatic library for writing
    parsers and lexers based on combinatory parsing. MaxPC is capable of
    parsing deterministic, context-free languages, provides powerful tools for
    parse tree transformation and error handling, and can operate on
    _sequences_ and _streams_. It supports unlimited backtracking, but does not
    implement [Packrat Parsing](http://pdos.csail.mit.edu/~baford/packrat/thesis/).
    Instead, MaxPC achieves good performance through its optimized primitives,
    and explicit separation of matching and capturing input. In practice, MaxPC
    parsers execute faster and require less total memory—when compared to
    Packrat parsers—at the expense of not producing linear-time parsers.²

    + 1. MaxPC is a complete rewrite of [MPC](https://github.com/eugeneia/mpc)
         with was in turn a fork of Drew Crampsie’s
         [Smug](http://smug.drewc.ca/).
    + 2. Unbacked claim: the book keeping costs of Packrat parsing diminish the
         gain in execution time for typical grammars and workloads.

    < Basic Concepts

     MaxPC _parsers_ are _functions_ that accept an [input](#section-4) as
     their only argument and return three values: the remaining _input_ or
     {nil}, a _result value_ or {nil}, and a _generalized boolean_ that
     indicates if a _result value_ is present. The _type_ of a parser is:

     {(function (}_input_{) (or} _input_ {null) * boolean)}

     A parser can either succeed or fail when applied to an input at a given
     position. A succeeding parser is said to _match_. When a parser matches it
     can optionally produce a _result value_, which may be processed by its
     parent parsers. New parsers can be created by composing existing parsers
     using built-in or user defined _parser combinators_. A parser combinator
     is a higher-order _function_ that includes one or more parsers as its
     arguments and returns a parser.

     By convention, all parsers are defined as higher-order _functions_ that
     return the respective parser, even if they are nullary. For instance, the
     {?end} parser is obtained using the form “{(?end)}”.

     A lexical convention is used to make three different types of parsers
     easily distinguishable:

     + Parsers whose names start with {?} never produce a result value.
     + Parsers whose names start with {=} always produce a result value.
     + Parsers whose names start with {%} may produce a result value depending
       on their arguments.

    >

    < Example

     We will define a parser for a simplistic grammar for Email addresses of
     the form:

     _email‑address_ := _user_ {@} _host_

     First we define a parser for the valid characters in the _user_ and _host_
     parts of an address. Just for this example, we choose these to be
     alphanumeric characters and then some. {?address‑character} uses the {%or}
     combinator to form the union of two instances of {?satisfies} that match
     different sets of characters.

     #code#
     (defun ?address-character ()
       (%or (?satisfies 'alphanumericp)
            (?satisfies (lambda (c)
                          (member c '(#\\- #\\_ #\\. #\\+))))))
     #

     Then we use {?address‑character} to implement our address parser which
     matches two sequences of “address characters” separated by an {@}
     character, and produces a list of user and host components as its result
     value. We match {?address‑character} one or more times using {%some}, and
     produce the matched subsequence as the result value using {=subseq}. Both
     parts of the address separated by an _@_ character are matched in sequence
     using {=list}, whose result value is finally transformed by
     {=destructure}.

     #code#
     (defun =email-address ()
       (=destructure (user _ host)
           (=list (=subseq (%some (?address-character)))
                  (?eq #\\@)
                  (=subseq (%some (?address-character))))
         (list user host))))
     #

     We can now apply {=email‑address} using {parse}:

     #code#
     (parse \"foo_bar@example.com\" (=email-address))
      ⇒ (\"foo_bar\" \"example.com\"), T, T
     (parse \"!!!@@@.com\" (=email-address))
      ⇒ NIL, NIL, NIL
     (parse \"foo_bar@example.com@baz\" (=email-address))
      ⇒ (\"foo_bar\" \"example.com\"), T, NIL
     #

    >

    < Overview

     {parse} is the entry point of {MaxPC}. It applies a parser to an input and
     returns the parser’s result value, and two _boolean_ values indicating if
     the parser matched and if there is unmatched input remaining,
     respectively.

     < Basic Parsers

      + {?end} matches only when there is no further input.
      + {=element} unconditionally matches the next element of the input
        _sequence_.
      + {?satisifies}, {?test}, and {?eq} match input conditionally.
      + {?not} negates its argument.
      + {%maybe} matches, even if its argument fails to match.
      + {=subseq} produces the subsequence matched by its argument as its
        result value.

     >

     < Logical Combinators

      + {%or} forms the union of its arguments.
      + {%and} forms the intersection of its arguments.
      + {%diff} forms the difference of its arguments.

     >

     < Sequence Combinators

      + {?list} matches its arguments in sequence.
      + {=list} matches its arguments in sequence and produces a list of their
        result as its result value.
      + {%any} matches its argument repeatedly any number of times.
      + {%some} matches its argument repeatedly one or more times.

     >

     < Transformation

      + {=transform} produces the result of applying a _function_ to its
        argument’s result value and its result value.
      + {=destructure} is a convenient destructuring _macro_ on top of
        {=transform}.

     >

     < Error Handling

      + {?fail} never matches and evaluates its body when it is called.
      + {%handler‑case} and {%restart‑case} allow you to set up _handlers_ and
        _restarts_ across parsers.
      + {get‑input‑position} can be called in error situations to retrieve the
        current position in the input.

     >

    >

    < Caveat: Recursive Parsers

     A recursive parser can not refer to itself by its constructor, but must
     instead call itself by _symbol_—calling its constructor would otherwise
     result in unbounded recursion. In order to do so the parser _function_
     needs to be _bound_ in the _function namespace_ using {setf}. The example
     below implements a parser for recursively matching parentheses, and
     illustrates how to avoid this common caveat.

     #code#
     (defun ?parens ()
       (?list (?eq #\\() (%maybe '?parens/parser) (?eq #\\)))))

     (setf (fdefinition '?parens/parser) (?parens))

     (parse \"((()))\" (?parens)) ⇒ NIL, T, T
     #

    >")
  (:use :cl :maxpc.input)
  (:export :parse
           :get-input-position
           :%handler-case
           :%restart-case
           :?end
           :=element
           :?fail
           :?satisfies
           :?test
           :?eq
           :?not
           :=subseq
           :=list
           :?list
           :%any
           :%some
           :%or
           :%and
           :%diff
           :%maybe
           :=transform
           :=destructure))

(defpackage maxpc.char
  (:documentation
   "Utility parsers for character inputs.")
  (:use :cl :maxpc)
  (:export :?char
           :?string
           :*whitespace*
           :?whitespace
           :%skip-whitespace
           :?newline
           :=line))

(defpackage maxpc.digit
  (:documentation
   "Parsers for digit numerals in character inputs.")
  (:use :cl :maxpc)
  (:export :?digit
           :=natural-number
           :=integer-number))

(defpackage maxpc.input.index
  (:use :cl :maxpc.input)
  (:export :index
           :position
           :index-position))

(defpackage maxpc.input.list
  (:use :cl :maxpc.input :maxpc.input.index))

(defpackage maxpc.input.array
  (:use :cl :maxpc.input :maxpc.input.index))

(defpackage maxpc.input.stream
  (:use :cl :maxpc.input :maxpc.input.index)
  (:export :*chunk-size*))
