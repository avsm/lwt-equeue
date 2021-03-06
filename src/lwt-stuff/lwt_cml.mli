(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*  David Nowak and Xavier Leroy, projet Cristal, INRIA Rocquencourt   *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in file ../../LICENSE.  *)
(*                                                                     *)
(***********************************************************************)

type 'a channel
(** The type of communication channels carrying values of type ['a]. *)

val new_channel : unit -> 'a channel
(** Return a new channel. *)

type 'a event
(** The type of communication events returning a result of type ['a]. *)

(** [send ch v] returns the event consisting in sending the value [v]
   over the channel [ch]. The result value of this event is [()]. *)
val send : 'a channel -> 'a -> unit event

(** [receive ch] returns the event consisting in receiving a value
   from the channel [ch]. The result value of this event is the
   value received. *)
val receive : 'a channel -> 'a event

val always : 'a -> 'a event
(** [always v] returns an event that is always ready for
   synchronization.  The result value of this event is [v]. *)

val never : 'a event
(** [never] is an event that is never ready for synchronization. *)

val choose : 'a event list -> 'a event
(** [choose evl] returns the event that is the alternative of
   all the events in the list [evl]. *)

val wrap : 'a event -> ('a -> 'b Lwt.t) -> 'b event
(** [wrap ev fn] returns the event that performs the same communications
   as [ev], then applies the post-processing function [fn]
   on the return value. *)

val wrap_abort : 'a event -> (unit -> unit) -> 'a event
(** [wrap_abort ev fn] returns the event that performs
   the same communications as [ev], but if it is not selected
   the function [fn] is called after the synchronization. *)

val guard : (unit -> 'a event) -> 'a event
(** [guard fn] returns the event that, when synchronized, computes
   [fn()] and behaves as the resulting event. This allows to
   compute events with side-effects at the time of the synchronization
   operation. *)

val sync : 'a event -> 'a Lwt.t
(** ``Synchronize'' on an event: offer all the communication 
   possibilities specified in the event to the outside world,
   and block until one of the communications succeed. The result
   value of that communication is returned. *)

val select : 'a event list -> 'a Lwt.t
(** ``Synchronize'' on an alternative of events.
   [select evl] is shorthand for [sync(choose evl)]. *)

val poll : 'a event -> 'a option
(** Non-blocking version of {!Lwt_cml.sync}: offer all the communication 
   possibilities specified in the event to the outside world,
   and if one can take place immediately, perform it and return
   [Some r] where [r] is the result value of that communication.
   Otherwise, return [None] without blocking. *)

type 'a basic_event =
  { poll: unit -> bool;
      (* If communication can take place immediately, return true. *)
    suspend: unit -> unit;
      (* Offer the communication on the channel and get ready
         to suspend current process. *)
    result: unit -> 'a Lwt.t }
      (* Return the result of the communication *)

type 'a behavior = int ref -> unit Lwt.u -> int -> 'a basic_event

val behavior : 'a behavior -> 'a event
