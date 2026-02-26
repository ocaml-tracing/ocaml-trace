(** Access/set the current span from some ambient context.
    @since 0.12 *)

open Types

module Callbacks = struct
  type 'st t = {
    with_current_span_set_to: 'a. 'st -> span -> (span -> 'a) -> 'a;
        (** [with_current_span_set_to span f] sets the span as current span,
            enters [f span], and restores the previous current span if any *)
    get_current_span: 'st -> span option;
        (** Access the current span from some ambient scope. This is only
            supported for collectors that provide a [current_span_wrap] field.
        *)
  }
end

type t =
  | ASP_none
  | ASP_some : 'st * 'st Callbacks.t -> t
