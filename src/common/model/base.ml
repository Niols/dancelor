(** {1 Base}

    Basic building blocks for models. *)

open Nes

module Password_clear = Fresh.Make(String)

module Password_reset_token_clear = struct
  include Fresh.Make(String)
  let make () = inject (uid ())
end

module Remember_me_key = struct
  include Fresh.Make(String)
  let make () = inject (uid ())
end

module Remember_me_token_clear = struct
  include Fresh.Make(String)
  let make () = inject (uid ())
end
