open Ids

module Person_name = struct
  type t = {
    id: Person_id.t;
    name: string;
  }
  [@@deriving eq, yojson, fields]
end

module Person_name_with_details = struct
  type t = {
    id: Person_id.t;
    name: string;
    details: string option; [@default None]
  }
  [@@deriving eq, yojson, fields]

  let to_name : t -> Person_name.t = fun {id; name; _} ->
    {id; name}
end

module Dance_name = struct
  type t = {
    id: Dance_id.t;
    name: string;
  }
  [@@deriving eq, yojson, fields]
end

module Source_name = struct
  type t = {
    id: Source_id.t;
    name: string;
  }
  [@@deriving eq, yojson, fields]
end

module Source_short_name = struct
  type t = {
    id: Source_id.t;
    short_name: string;
  }
  [@@deriving eq, yojson, fields]
end

module Tune_name = struct
  type t = {
    id: Tune_id.t;
    name: string;
  }
  [@@deriving eq, yojson, fields]
end

module Version_name = struct
  type t = {
    id: Version_id.t;
    name: string;
  }
  [@@deriving eq, yojson, fields]
end

module Set_name = struct
  type t = {
    id: Set_id.t;
    name: string;
  }
  [@@deriving eq, yojson, fields]
end

module Book_name = struct
  type t = {
    id: Book_id.t;
    name: string;
  }
  [@@deriving eq, yojson, fields]
end

module User_name = struct
  type t = {
    id: User_id.t;
    username: string;
  }
  [@@deriving eq, yojson, fields]
end
