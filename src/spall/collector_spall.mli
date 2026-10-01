type t

val create :
  pid:int ->
  oc:out_channel ->
  ?close_oc:bool ->
  ?high_water_mark:int ->
  unit ->
  t

val collector : t -> Trace_core.Collector.t
val close : t -> unit
