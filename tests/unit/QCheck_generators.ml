open QCheck2

module Id = struct
  type 'tag t = [%import: 'tag Dancelor_common.Id.t]

  let gen _ =
    let open Gen in
    (* generate 11 digits in base 36 *)
    flatten_list (List.init 11 (fun _ -> int_range 0 35)) >>= fun digits ->
    (* add the checksum digit in front *)
    let digits = ((36 - ((List.fold_left (+) 0 digits) mod 36)) mod 36) :: digits in
    (* turn the digits into alphanumerals *)
    let alphanumerals = List.map (fun n -> Char.chr (if n < 10 then Char.code '0' + n else Char.code 'a' + n - 10)) digits in
    (* make a string of the form 0000-0000-0000 *)
    let str = Bytes.make 14 '-' in
    for i = 0 to 3 do Bytes.set str i (List.nth alphanumerals i) done;
    for i = 5 to 8 do Bytes.set str i (List.nth alphanumerals (i - 1)) done;
    for i = 10 to 13 do Bytes.set str i (List.nth alphanumerals (i - 2)) done;
    let str = Bytes.unsafe_to_string str in
    (* convert to and id (which will check it), and we're done! *)
    pure @@ Option.get @@ Dancelor_common.Id.of_string str
end

module Entry = struct
  (* The following are dirty tricks, necessary to convince [ppx_deriving_qcheck]
     that it can generate an [t Id.t]. These “models” are only to be used in a
     context where we use their id; there, it is fine since [Id.gen] ignores its
     first argument. *)

  module User = struct
    (* FIXME: not sure this one is actually fine *)
    type t = Dancelor_common.User_tag.t
    let gen : t QCheck2.Gen.t = Gen.pure (Obj.magic 0)
  end
end

module Kind = struct
  module Base = struct
    type t = [%import: Dancelor_common.Kind.Base.t] [@@deriving qcheck2]
  end

  module Version = struct
    type t = [%import: Dancelor_common.Kind.Version.t]

    let gen = Gen.(pair nat Base.gen)
  end

  module Dance = struct
    type t = [%import: Dancelor_common.Kind.Dance.t]

    let gen =
      let open Gen in
      let open Dancelor_common.Kind.Dance in
      sized @@
      fix @@ fun self ->
      function
        | 0 -> version <$> Version.gen
        | n ->
          oneof
            [
              (add <$> self (n / 2) <*> self (n / 2));
              (mul <$> nat <*> self (n - 1));
            ]
  end
end

module Model = struct
  (* The following are dirty tricks, necessary to convince [ppx_deriving_qcheck]
     that it can generate an [t Id.t]. These “models” are only to be used in a
     context where we use their id; there, it is fine since [Id.gen] ignores its
     first argument. *)

  module Source = struct
    type t = Dancelor_common.Source_tag.t
    let gen : t QCheck2.Gen.t = Gen.pure (Obj.magic 0)
  end

  module Person = struct
    type t = Dancelor_common.Person_tag.t
    let gen : t QCheck2.Gen.t = Gen.pure (Obj.magic 0)
  end

  module Dance = struct
    type t = Dancelor_common.Dance_tag.t
    let gen : t QCheck2.Gen.t = Gen.pure (Obj.magic 0)
  end

  module Tune = struct
    type t = Dancelor_common.Tune_tag.t
    let gen : t QCheck2.Gen.t = Gen.pure (Obj.magic 0)
  end

  module Version = struct
    type t = Dancelor_common.Version_tag.t
    let gen : t QCheck2.Gen.t = Gen.pure (Obj.magic 0)
  end

  module Set = struct
    type t = Dancelor_common.Set_tag.t
    let gen : t QCheck2.Gen.t = Gen.pure (Obj.magic 0)
  end

  module Book = struct
    type t = Dancelor_common.Book_tag.t
    let gen : t QCheck2.Gen.t = Gen.pure (Obj.magic 0)
  end

  module Any = struct
    module Type = struct
      type t = [%import: Dancelor_common.Any_id.Type.t [@with Dancelor_common.Formula.t := Formula.t;]
      ]
      [@@deriving qcheck2]
    end
  end
end
