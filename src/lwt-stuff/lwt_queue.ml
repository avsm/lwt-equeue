(*
 * This file is part of orpc, OCaml signature to ONC RPC generator
 * Copyright (C) 2008-9 Skydeck, Inc
 * Copyright (C) 2010 Jacob Donham
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
 * MA 02111-1307, USA
 *)

let (>>=) = Lwt.(>>=)

type 'a t = { m : Lwt_mutex.t; c : unit Lwt_condition.t; q : 'a Queue.t }

exception Timeout

let create () = { m = Lwt_mutex.create (); c = Lwt_condition.create (); q = Queue.create () }

let add e t =
  Queue.add e t.q;
  Lwt_condition.signal t.c ()

let take ?(timeout=(-1.)) t =
  let timed_out = ref false in
  if timeout >= 0.
  then
    Lwt.ignore_result
      (Lwt_unix.sleep timeout >>= fun () ->
        timed_out := true;
        Lwt_condition.broadcast t.c ();
        Lwt.return ());
  Lwt_mutex.lock t.m >>= fun () ->
    let rec while_empty () =
      if !timed_out then Lwt.return false
      else if not (Queue.is_empty t.q) then Lwt.return true
      else Lwt_condition.wait ~mutex:t.m t.c >>= while_empty in
    while_empty () >>= fun not_empty ->
      let e = if not_empty then Some (Queue.take t.q) else None in
      Lwt_condition.signal t.c ();
      Lwt_mutex.unlock t.m;
      match e with Some e -> Lwt.return e | _ -> Lwt.fail Timeout
