#!/usr/bin/env /home/pete/bin/roboto

(def record

(frdef determine-cmd ()
       (([^rec]i ...) *...) record
)

(= args (dup argv))
(= cmd (determine-cmd args))

(when (nil? cmd) 
  (fatal! "Command doesn't make sense:  #(args)"))

(cmd)
