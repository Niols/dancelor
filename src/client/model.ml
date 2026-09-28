module Getters = struct
  let get_user = Api.call_or_option (User Get)
  let get_book = Api.call_or_option (Book Get)
  let get_dance = Api.call_or_option (Dance Get)
  let get_person = Api.call_or_option (Person Get)
  let get_set = Api.call_or_option (Set Get)
  let get_source = Api.call_or_option (Source Get)
  let get_tune = Api.call_or_option (Tune Get)
  let get_version = Api.call_or_option (Version Get)
end

include Dancelor_common.Model_builder.Build(Getters)
