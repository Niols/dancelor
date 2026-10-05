open NesUnix
include Dancelor_common

module type Fresh_hashed_secret_clear = sig
  type t
  val project : t -> string
end

module Make_fresh_hashed_secret (Clear : Fresh_hashed_secret_clear) = struct
  include Fresh.Make(HashedSecret)
  let make ~clear = inject @@ HashedSecret.make ~clear: (Clear.project clear)
  let is ~clear hash = HashedSecret.is ~clear: (Clear.project clear) (project hash)
end

module Password_hash = Make_fresh_hashed_secret(Password_clear)
module Password_reset_token_hash = Make_fresh_hashed_secret(Password_reset_token_clear)
module Remember_me_token_hash = Make_fresh_hashed_secret(Remember_me_token_clear)
